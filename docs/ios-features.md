# iOS feature plan

Principle from the product: **used mostly on a phone, on the move.** Features are chosen for one-handed,
glanceable, low-attention use — and for things a mobile web page cannot do.

## Phase 1 — foundation (this repo today)

| Feature | API | Why it matters | State |
|---|---|---|---|
| Lock-screen narration + controls | AVAudioSession `.spokenAudio`, `MPNowPlayingInfoCenter`, `MPRemoteCommandCenter` | Walk with the phone in a pocket | Written, unverified |
| Arrival alerts | `CLCircularRegion` monitoring, `UNUserNotificationCenter` | Right stop, right moment, no GPS polling | Written, unverified |
| Walking routes from every Metro exit | `MKDirections` `.walking` | Replaces estimates and the public OSRM demo server | Written, unverified |
| Tour maps with real routes | SwiftUI `Map`, `MapPolyline` | Orientation | Written, unverified |
| Resume by voice / Spotlight | App Intents, Core Spotlight | "Resume my tour" with no setup | Written, unverified |
| Accessibility | Dynamic Type, VoiceOver labels, adjustable scrubber | Wide audience, 8 languages | Partly written |
| Haptics | `sensoryFeedback`, `UINotificationFeedbackGenerator` | Arrival you can feel | Written, unverified |
| Privacy manifest | `PrivacyInfo.xcprivacy` | Required for submission | Done |

## Phase 2 — paid, offline, glanceable

| Feature | API | Notes |
|---|---|---|
| Purchases | StoreKit 2 + server verification | See backend-requirements.md #2–3 |
| Account | Sign in with Apple + Firebase Auth | One entitlement across web and iOS |
| Offline packs | background `URLSession` | Underground stretches and weak signal; the commute use case |
| Live Activity / Dynamic Island | ActivityKit | "Next stop: 90 m" on the lock screen |
| UI localization | String Catalog | Port the web app's `locales/*.json`; tour content already has 8 languages |
| Firestore content | Firebase iOS SDK | Replace `BundledContent`; offline persistence is built in |

## Phase 3 — expansion

| Feature | API | Notes |
|---|---|---|
| Events near your station | Firestore + geohash | The reason to open the app on days you aren't touring |
| Home-screen widget | WidgetKit | Next train + tonight's event |
| Apple Watch | watchOS | Haptic turn cues; remote for playback |
| CarPlay | CarPlay audio | Requires an Apple-approved entitlement; useful for day-trip drives |
| Shareable stops | Universal Links | Needs an `apple-app-site-association` on dcaudiotours.com |

## Deliberately not planned

- **Geofencing sub-stops.** They're rooms and exhibits inside buildings; GPS indoors is unreliable and the catalog has
  no coordinates for them. They stay as an in-stop list with their own audio.
- **Bundling the 600 MB of audio.** Stream, and download per tour for offline.
- **Android parity.** The web app covers it for now.
