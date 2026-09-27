#!/usr/bin/env python3
"""Portable source/package integrity checks. This does not compile Swift."""
from pathlib import Path
import json
import plistlib
import re
import struct
import subprocess
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]

# Parse this project's OpenStep property list independently of its generator.
source = (root / 'TagLookup.xcodeproj/project.pbxproj').read_text()
source = re.sub(r'//[^\n]*', '', source)
tokens = re.findall(r'"(?:\\.|[^"\\])*"|[{}()=;,]|[^\s{}()=;,]+', source)
position = 0

def take(expected=None):
    global position
    token = tokens[position]
    position += 1
    if expected is not None:
        assert token == expected, (token, expected)
    return token

def parse():
    token = take()
    if token == '{':
        result = {}
        while tokens[position] != '}':
            key = parse()
            take('=')
            assert key not in result, f'Duplicate key: {key}'
            result[key] = parse()
            take(';')
        take('}')
        return result
    if token == '(':
        result = []
        while tokens[position] != ')':
            result.append(parse())
            if tokens[position] == ',':
                take(',')
        take(')')
        return result
    return json.loads(token) if token.startswith('"') else token

project = parse()
assert position == len(tokens)
objects = project['objects']
assert objects[project['rootObject']]['isa'] == 'PBXProject'
paths = {}

def visit(identifier, parent):
    obj = objects[identifier]
    if obj['isa'] == 'PBXGroup':
        current = parent / obj.get('path', '')
        for child in obj['children']:
            visit(child, current)
    elif obj['isa'] == 'PBXFileReference' and obj['sourceTree'] == '<group>':
        file = parent / obj['path']
        assert file.exists(), f'Missing project member: {file}'
        paths[identifier] = file

visit(objects[project['rootObject']]['mainGroup'], root)
target = next(o for o in objects.values() if o['isa'] == 'PBXNativeTarget')
source_phase = next(objects[x] for x in target['buildPhases'] if objects[x]['isa'] == 'PBXSourcesBuildPhase')
source_paths = {paths[objects[x]['fileRef']] for x in source_phase['files']}
expected_sources = set((root/'App').glob('*.swift')) | set((root/'Core').glob('*.swift'))
assert source_paths == expected_sources, 'Source build phase does not match app/core files'
assert len(source_phase['files']) == len(source_paths), 'Duplicate compiled source'
resources = next(objects[x] for x in target['buildPhases'] if objects[x]['isa'] == 'PBXResourcesBuildPhase')
resource_paths = {paths[objects[x]['fileRef']] for x in resources['files']}
assert resource_paths == {root/'Resources/Assets.xcassets', root/'Resources/PrivacyInfo.xcprivacy'}
configs = objects[target['buildConfigurationList']]['buildConfigurations']
for identifier in configs:
    settings = objects[identifier]['buildSettings']
    assert settings['PRODUCT_BUNDLE_IDENTIFIER'] == 'com.brody.taglookup'
    assert settings['IPHONEOS_DEPLOYMENT_TARGET'] == '16.0'
    assert settings['GENERATE_INFOPLIST_FILE'] == 'YES'

scheme = ET.parse(root/'TagLookup.xcodeproj/xcshareddata/xcschemes/TagLookup.xcscheme')
for ref in scheme.findall('.//BuildableReference'):
    assert objects[ref.attrib['BlueprintIdentifier']] is target
    assert ref.attrib['BuildableName'] == 'TagLookup.app'
ET.parse(root/'TagLookup.xcodeproj/project.xcworkspace/contents.xcworkspacedata')

privacy = plistlib.loads((root/'Resources/PrivacyInfo.xcprivacy').read_bytes())
assert privacy['NSPrivacyTracking'] is False
assert privacy['NSPrivacyAccessedAPITypes'][0]['NSPrivacyAccessedAPITypeReasons'] == ['CA92.1']
for contents in (root/'Resources/Assets.xcassets').rglob('Contents.json'):
    metadata = json.loads(contents.read_text())
    for item in metadata.get('images', []):
        png = (contents.parent/item['filename']).read_bytes()
        assert png[:8] == b'\x89PNG\r\n\x1a\n'
        width, height = struct.unpack('>II', png[16:24])
        expected = int(float(item['size'].split('x')[0]) * int(item['scale'][:-1]))
        assert (width, height) == (expected, expected)
        assert png[25] == 2, 'App icons must be opaque RGB'

client = (root/'Core/PlayFabClient.swift').read_text()
assert set(re.findall(r'case \w+ = "(Get\w+)"', client)) == {'GetAccountInfo', 'GetUserInventory'}
assert 'https://63FDD.playfabapi.com/Client/' in client
assert 'func ownInventory(ticket: String)' in client
assert 'call(.inventory, ticket: ticket, body: [:])' in client
assert 'completionHandler(nil)' in client
for path in expected_sources:
    text = path.read_text()
    for forbidden in ['X-SecretKey', '/Server/', '/Admin/', 'LoginWithCustomID', 'LoginWithCustomId', 'ExecuteCloudScript']:
        assert forbidden not in text, (path.name, forbidden)
    assert not re.search(r'\b(print|debugPrint|NSLog)\s*\(', text), f'Unexpected runtime log: {path}'
app = (root/'App/AppModel.swift').read_text()
assert 'JSONEncoder().encode(saved)' in app
assert 'UserDefaults.standard.set(ticket' not in app
assert 'kSecAttrAccessibleWhenUnlockedThisDeviceOnly' in (root/'App/KeychainVault.swift').read_text()
assert 'kSecAttrSynchronizable as String: false' in (root/'App/KeychainVault.swift').read_text()

subprocess.run(['bash', '-n', str(root/'scripts/build-ipa.sh')], check=True)
test_count = len(re.findall(r'func test\w+\(', (root/'Tests/ClientTests.swift').read_text()))
assert test_count >= 10
assert (root/'.github/workflows/build-ios.yml').is_file()
print(f'Source integrity passed: {len(source_paths)} Swift source files, {test_count} defined Swift tests, project references, assets, privacy manifest, endpoint scope, and build-script syntax.')
print('Swift compilation, Swift test execution, iPhone installation, and live service access were NOT checked by this script.')
