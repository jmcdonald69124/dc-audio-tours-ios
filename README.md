# DC Audio Tours — iOS

Native iPhone app for [DC Audio Tours](https://dcaudiotours.com): self-guided, narrated walking tours of
Washington, DC, built around the Metro, in 8 languages (English, Español, Français, Deutsch, 日本語, 한국어, 中文, Português).

Built in SwiftUI for iOS 17+. The web app and the backend live in
[`metro-events`](https://github.com/jmcdonald69124/metro-events); this repo is the native client.

> **Status: foundation.** The core library is tested (32 tests). The SwiftUI app **compiles** — CI builds it
> for the iOS Simulator on every push (Xcode 26.6, no warnings) — but it has **not been run yet**: audio
> playback, geofence arrival and the MapKit routes are untested on a simulator or device. Run it and report what
> misbehaves; that is the next round of fixes.

## Why native

The web app already does tours well. A native app earns its place with things a browser can't do:

| Feature | iOS API | State |
|---|---|---|
| Narration keeps playing with the screen locked; lock-screen / Control Center / headphone controls | AVFoundation, MediaPlayer | Compiles; not yet run |
| **Arrival detection** — phone tells you when you reach the next stop, screen off | Core Location geofences + local notifications | Compiles; not yet run |
| **Real walking directions** from each Metro exit to each stop, and between stops on neighborhood walks | MapKit `MKDirections` (`.walking`), hand-off to Apple Maps | Compiles; not yet run |
| Numbered-stop maps with real routes | SwiftUI `Map`, `MapPolyline` | Compiles; not yet run |
| "Resume my tour" by voice; tours in Spotlight search | App Intents, Core Spotlight | Compiles; not yet run |
| Dynamic Type, VoiceOver labels, haptics | SwiftUI | Compiles; not yet run |
| In-app purchase, Sign in with Apple, shared entitlements with the web | StoreKit 2, Firebase Auth | Planned (phase 2) |
| Offline tour packs | background `URLSession` | Planned (phase 2) |
| Live Activity: "next stop in 90 m" on the lock screen | ActivityKit | Planned (phase 2) |
| Events near your station | Firestore | Planned (phase 3) |

See [docs/ios-features.md](docs/ios-features.md) for the full list and reasoning.

## Run it

Requires a Mac with Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
xcodegen generate              # creates DCAudioTours.xcodeproj from project.yml
open DCAudioTours.xcodeproj    # set your team under Signing & Capabilities, then run
```

Run the core tests without Xcode (Linux or macOS):

```bash
swift test --package-path Packages/TourKit
```

## Languages

Tour content *and* the interface are in 8 languages (en, es, fr, de, ja, ko, zh-Hans, pt-BR), switchable in the
app independently of the phone's language. `Localization/strings.json` is the source of truth (29 strings reuse
the web app's translations; the rest are new); `scripts/build-strings.py` generates the String Catalogs and
`scripts/check-strings.py` (CI) fails on a missing translation, a mismatched `%@`/`%lld`, or a Swift string that
bypasses localization. Translations were machine-authored and have not had a native-speaker review.
Known gap: walking-route notes and exit directions in the catalog are English-only (as on the web).

## Layout

```
Packages/TourKit/        Pure-Swift core: models, access rules, geofence planner, audio file naming.
                         No UIKit/Firebase — builds and tests on Linux. 32 tests, including data-quality
                         checks that decode the real bundled content.
App/DCAudioTours/        SwiftUI app: services (audio, location, directions), views, resources.
  Resources/Content/     Bundled catalog + per-language text (generated — see below).
docs/                    Architecture, Firestore schema, what the backend must add.
project.yml              XcodeGen spec (the .xcodeproj is generated and not committed).
```

## Content

`App/DCAudioTours/Resources/Content/` is **generated** from the web repo's tour data — don't edit it by hand:

```bash
# in metro-events
node scripts/export-ios-content.mjs --out ../dc-audio-tours-ios/App/DCAudioTours/Resources/Content
swift test --package-path Packages/TourKit     # in this repo: validates the new export
```

The export writes `catalog.json` (tours, stops, coordinates, route legs, audio file keys) and
`content/<lang>.json` (narration, tips, sub-stop text for **one** language each, ~330–510 KB).
The same shape is what Firestore will serve in phase 2 ([schema](docs/firestore-schema.md)).

Audio is **streamed** from `https://dcaudiotours.com/audio/…`; free stops need no token. The 952 MP3s
(~600 MB) are not bundled.

## Known data issues

Found by the data tests; they are content decisions, not code bugs:

- **`music-lovers/songbyrd`** — the tour describes the Adams Morgan café (12 min from Woodley Park) but
  the geocode points to "Songbyrd Music House, 540 Penn St NE", ~5.5 km away. Either the text is stale or the
  coordinate is wrong. Tracked in `knownDistanceProblems` in `ContentTests.swift`.
- **All stop coordinates are geocoded (Nominatim) and unreviewed.** 11 groups of stop ids share one
  coordinate (mostly the same place under different tour ids); a few stops are approximated to a nearby landmark
  or intersection. Fine for a 150 m arrival radius, not for turn-by-turn to a door.
- Area-tour leg times in the catalog are street-grid *estimates*; the app uses live MapKit routes instead.

## Before App Store submission

- [ ] Confirm bundle id (`com.fettink.dcaudiotours` is a guess) and set `DEVELOPMENT_TEAM`.
- [ ] Privacy policy URL (required) and App Privacy answers; `PrivacyInfo.xcprivacy` is included.
- [ ] App icon: current one is a placeholder derived from the web logo — needs a designer pass.
- [ ] In-app purchase for paid tours (Apple requires IAP for digital content unlocked in-app) — phase 2.
- [ ] Localize UI strings (String Catalog) — tour *content* is already in 8 languages, UI chrome is English.
- [ ] Review guidelines check for background location ("Always") justification text.
