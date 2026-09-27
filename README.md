# Tag Lookup

Native iPhone companion for exact Gorilla Tag PlayFab account lookups.

## Build the IPA

Open **Actions → Build iOS IPA** and open the latest run. After a successful build,
download the **TagLookup-unsigned-IPA** artifact and extract the ZIP. The included
`TagLookup-unsigned.ipa` needs signing through your sideloading app before installation.

The workflow also supports **Run workflow** for another build. It uses a GitHub
Mac runner and does not need Apple or PlayFab credentials to compile the app.

[Build verified on 2026-09-27](https://github.com/biirf8/TagLookup/actions/runs/36320607783):
all 12 Swift tests passed, Xcode compiled the app, and the unsigned ARM64 IPA
passed archive validation. Live authenticated requests and iOS 27 device testing
remain untested.

## Features

- Exact player ID lookup and conditional exact account-name lookup.
- Returned display name, PlayFab ID, and exposed linked-platform fields.
- Saved player results with local name/ID filtering and copyable IDs.
- The connected account's own inventory, including returned cosmetics.
- Optional device-only Keychain session storage.

Live queries require a valid client session ticket from your own authorized Gorilla
Tag session. This project does not provide a standalone Gorilla Tag sign-in flow.
The title/server IDs alone do not grant account access. Gorilla Tag's client API
policy might reject a request even with a valid session.

Full player-database browsing and other players' inventories are excluded. Linked
platforms do not identify the current headset, and hidden fields stay unknown.
No secret-key, Server/Admin, custom-ID login, or room-scanning calls are included.

## Local development

Open `TagLookup.xcodeproj` in Xcode. Minimum deployment target: iOS 16.0.
Actual iOS 27 device testing is pending.

```sh
python3 scripts/check-source.py
swift test
bash scripts/build-ipa.sh
```

See [README.txt](README.txt) for setup and API details, and [VALIDATION.txt](VALIDATION.txt)
for the validation record. Unofficial project with no affiliation with Another Axiom.
