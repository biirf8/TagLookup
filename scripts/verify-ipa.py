#!/usr/bin/env python3
"""Reject a source-only or simulator-only archive masquerading as an IPA."""
import plistlib
import struct
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as archive:
    assert archive.testzip() is None, "Corrupt ZIP member"
    root = "Payload/TagLookup.app/"
    info = plistlib.loads(archive.read(root + "Info.plist"))
    assert info["CFBundleIdentifier"] == "com.brody.taglookup"
    assert info["CFBundleExecutable"] == "TagLookup"
    assert info["CFBundleSupportedPlatforms"] == ["iPhoneOS"]
    executable = archive.read(root + "TagLookup")
    assert len(executable) > 4096, "Missing real executable"
    magic, cpu = struct.unpack_from("<II", executable)
    assert magic == 0xFEEDFACF, "Expected a thin 64-bit Mach-O"
    assert cpu == 0x0100000C, "Expected an ARM64 device executable"
    assert root + "PrivacyInfo.xcprivacy" in archive.namelist()
print("IPA structure, device platform, and ARM64 executable verified.")
