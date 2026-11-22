# Architecture

```
┌──────────────────────────── SwiftUI views ─────────────────────────────┐
│ ToursView · TourDetailView · StopView · NearbyView · Player · Settings │
└───────────────▲─────────────────────────────────────────▲──────────────┘
                │ @Environment(AppModel)                  │ App Intents / notifications / lock screen
        ┌───────┴────────┐                                │
        │   AppModel     │ ◄──────────────────────────────┘   (@Observable, @MainActor, single source of truth)
        └─┬───────┬────┬─┘
          │       │    │
   AudioPlayer  Location  WalkingDirections          BundledContent  →  (phase 2) Firestore repository
   (AVPlayer)  (CoreLocation) (MapKit)                    │
          └───────┴────┴────────────── TourKit ◄───────────┘
                   models · AccessPolicy · GeofencePlanner · AudioFiles · TourProgress  (pure Swift)
```

## Layers

**TourKit** (`Packages/TourKit`) — everything that can be decided without a device: the content
model, "which stops may this listener play", "which 18 stops should the phone watch next", audio file
naming, progress. No UIKit, no Firebase. It is Swift 6 and builds on Linux, so it is tested in CI in seconds.
Keeping rules here (not in views) is what lets the iOS app and the web server agree.

**App** (`App/DCAudioTours`) — Swift 5 language mode for now (young codebase, fewer concurrency
diagnostics while it is being compiled for the first time); services are `@MainActor`, delegate callbacks
hop to the main actor. Move to Swift 6 mode once it builds clean.

## Access rules (must match the server)

`AccessPolicy` mirrors `isAudioAllowed` in the web repo's `server/app.js`:

1. The first stop of **every** tour is free (a stop id that is first in any tour is free everywhere).
2. Every stop of the free tour (`museums-monuments`) is free.
3. Otherwise the listener must own a tour that contains the stop, or the all-access pass.

Stops are shared between tours (area walks reuse themed-tour stops), so ownership is evaluated per
*stop id across tours*, exactly as the server does. If the server's rule changes, change `AccessPolicy` and its
tests in the same commit.

> The narration **text** is bundled for all tours (it is also in the web app's JS bundle today). The paid
> value is the audio; the text is not protected.

## Audio

- Stop files: `<stem>-<lang>.mp3`, where stems come from `Stop.audioKeys` (tour-prefixed first when a stop id
  is used by several tours, plain id as fallback). Sub-stop clips: `<stopId>-sub-<subId>[-directions]-<lang>.mp3`.
- `AudioPlayerService` tries each candidate URL in order — a 403/404 on the first falls through to the next.
- `AVAudioSession` category `.playback`, mode `.spokenAudio`; interruptions and headphone-unplug handled;
  Now Playing + remote commands (±15 s, scrub, rate, next/previous **stop**).

## Arrival detection

iOS allows 20 monitored regions per app. `GeofencePlanner` picks the next ≤18 upcoming stops (route order) or
the nearest ones; `AppModel.replanGeofences()` re-targets them after each completed stop. Radius is clamped to
≥100 m (Apple's reliability guidance). Regions sit on **stops**, never on sub-stops — those are rooms inside
buildings, where GPS is unreliable and the data has no coordinates.

"Always" location is needed for background arrival alerts; the app asks for When-In-Use first and offers the
upgrade from Settings, after the listener has seen the value.

## Walking directions

Every stop has the coordinates of its Metro station (`stationLocation`) and its own (`location`), so any stop can
show a live Apple Maps walking route *from the station exit*. Neighborhood walks also route between consecutive
stops and draw the polylines on the tour map. The catalog's own leg times are street-grid estimates, shown only as
a fallback summary.

## Content pipeline

`metro-events/scripts/export-ios-content.mjs` → `catalog.json` + `content/<lang>.json` → bundled in the app
(phase 1) and seeded to Firestore (phase 2). One schema for both: see [firestore-schema.md](firestore-schema.md).
