TAG LOOKUP FOR IPHONE
Version 1.0.0

DELIVERY STATUS
This folder contains native SwiftUI source, an Xcode project, tests, and an
automated IPA build workflow. No compiled IPA is included. The development
workspace did not have Xcode or an iOS SDK. The Swift tests and iOS build have
not run here. The workflow runs both on a Mac runner.

The project targets iOS 16.0 and later using standard native APIs. iOS 27
device compatibility has not been tested. No JIT or jailbreak is required by
the app. An unsigned device IPA still needs signing before installation.

BEFORE BUILDING
Live lookup needs a current PlayFab client session ticket belonging to your
own authorized Gorilla Tag account. This app does not include a Gorilla Tag
login flow or generate tickets from server IDs. There is no official standalone
mobile sign-in integration established for this project.

Your attached file provides title and Photon application identifiers.
Those identifiers do not grant player access. The project uses only the
supplied production PlayFab title ID, 63FDD. It does not use the development
title, voice/realtime server identifiers, or the custom authentication URL.
Do not put session tickets in source files or GitHub. Enter one only inside
the app after installation. A title secret key is never needed or accepted
as a dedicated setting.

WHAT IS IMPLEMENTED
- Look up one exact PlayFab player ID.
- Attempt exact account display-name lookup. This is not partial-name search.
  A title with non-unique display names rejects name lookup. An in-game
  Gorilla Tag nickname is not guaranteed to equal the PlayFab account name.
- Show the returned account display name and PlayFab ID.
- Show linked Steam, PlayStation, Android, iOS, or Xbox account fields only
  when returned. These are linked account platforms, not current device data.
  Missing fields display Not exposed. Android is not assumed to mean Quest.
- Save up to 100 lookup results on this device, filter them, copy IDs, and
  remove records. Saved results show their last fetch time and work offline.
- Read the connected account's own legacy inventory, including any cosmetics
  returned by that endpoint. Filter by name or item ID. No equipped status is
  inferred. Inventory is held in memory and cleared when disconnected.
- Save an optional client session in this device's Keychain. Disconnect clears
  the active session and attempts to delete the stored credential.

WHAT IS EXCLUDED
- Browsing or enumerating the entire Gorilla Tag player database.
- Other players' cosmetic inventories or equipped cosmetic lists.
- Current headset/platform guesses, online status, room tracking, server scans.
- Secret keys, Admin/Server APIs, authentication bypasses, account creation,
  or guessed custom-ID logins.

Availability depends on Gorilla Tag's current client API policies. Microsoft
documents these client endpoints, but this project has not authenticated to
Gorilla Tag or verified its live permissions. The game might block a lookup
even with a valid client ticket. The app displays an access error in that case.

BUILD AN IPA WITHOUT OWNING A MAC
1. Create an empty GitHub repository.
2. Put the CONTENTS of this folder at the repository root. Include .github,
   App, Core, Resources, Tests, scripts, TagLookup.xcodeproj, and Package.swift.
   Do not upload the ZIP alone. On Windows, extract the ZIP first. The .github
   folder must be included for the build workflow to appear.
3. Open the repository's Actions tab. Enable workflows if GitHub asks.
4. Select Build iOS IPA, then Run workflow.
5. Open the finished run. Download the TagLookup-unsigned-IPA artifact.
6. Extract the artifact ZIP. It contains TagLookup-unsigned.ipa after a
   successful build. Sign/install using your chosen sideloading app.

The workflow uses a hosted Mac, runs fixture tests, compiles an ARM64 device
binary, packages the IPA, and validates the archive before uploading it.
No Apple credentials or PlayFab credentials are used during the build.
GitHub account limits and runner availability still apply.

BUILD ON A MAC
Install full Xcode and finish its first-run setup. Open a terminal in this
folder and run:

  bash scripts/build-ipa.sh

Output after a successful build:

  build/TagLookup-unsigned.ipa

For a direct Xcode installation, open TagLookup.xcodeproj, select the TagLookup
scheme, select your iPhone, and choose your development team under Signing &
Capabilities. Change the bundle identifier if your signing setup requires it.
Build and run using Xcode. The command-line IPA build deliberately skips signing.

USE THE APP
1. Open Session. Paste your current authorized client session ticket.
2. Leave Remember enabled to save the credential in this iPhone's Keychain,
   or disable Remember for this launch only. Tap Connect.
3. In Lookup, enter a PlayFab ID and tap Find player.
4. Bookmark a successful result. Open Saved to search your saved records.
5. In My items, tap Refresh my items to request your own inventory.
6. If a session expires, return to Session and connect a current ticket.

Your ticket is sensitive account access data. The app sends it directly to
https://63FDD.playfabapi.com in the X-Authorization header. There is no proxy,
analytics, remote app server, credential export, or background player scan.
Redirects are rejected. Response bodies and credentials are not logged.
Offline saved player records are separate from the credential and are retained
until removed. Keychain data does not sync to iCloud. Disconnect is the explicit
way to remove the saved session, including after reinstalling the application.

FILES
App/                 SwiftUI screens, session state, and Keychain storage
Core/                Client request code and filtered data models
Tests/               Fixture-based Swift tests, no live credentials
Resources/           App icon and privacy manifest
TagLookup.xcodeproj  Native Xcode project and shared build scheme
scripts/             Mac IPA builder, IPA validator, source checks
.github/workflows/   GitHub Actions build workflow

PRIMARY API REFERENCES, CHECKED 2026-09-27
https://learn.microsoft.com/en-us/rest/api/playfab/client/account-management/get-account-info?view=playfab-rest
https://learn.microsoft.com/en-us/rest/api/playfab/client/player-item-management/get-user-inventory?view=playfab-rest
https://learn.microsoft.com/en-us/rest/api/playfab/server/player-item-management/get-user-inventory?view=playfab-rest
https://learn.microsoft.com/en-us/rest/api/playfab/server/play-stream/get-all-segments?view=playfab-rest
https://docs.github.com/en/actions/reference/runners/github-hosted-runners

Unofficial personal companion project. No affiliation with Another Axiom.
