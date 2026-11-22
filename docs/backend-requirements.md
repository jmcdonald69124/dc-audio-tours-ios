# What the backend (metro-events) needs for iOS

Phase 1 needs **nothing** from the backend: content is bundled and free audio streams from the existing
`/audio/:file` endpoint. Everything below is for phase 2+.

| # | Work | Why | Notes |
|---|---|---|---|
| 1 | `scripts/export-ios-content.mjs` | Source of the bundled content and the Firestore seed | **Done** (on branch `claude/ios-content-export`). Add a `--write` mode that seeds Firestore. |
| 2 | **App Store transaction verification** — `POST /api/ios/entitlements/sync` | Unlock paid tours after an in-app purchase | Verify StoreKit 2 signed transactions (JWS) server-side with Apple's App Store Server Library; write `users/{uid}/entitlements`. Never trust the client. |
| 3 | **App Store Server Notifications V2** webhook | Refunds, revocations, family sharing | Marks entitlements `revokedAt`; mirrors what the Stripe `charge.refunded` handler does. |
| 4 | **Audio token for iOS** — `GET /api/ios/audio-token` | Paid audio streams only for owners | Verify the Firebase ID token with `firebase-admin`, return the existing HMAC token for the user's tour ids. Reuse `mintAudioToken`. |
| 5 | Restore web purchases (email one-time code) | A web buyer opens the iOS app | See "Linking" in firestore-schema.md. Replace the current email-only `/api/tour/restore`, which anyone who knows a buyer's email can call. |
| 6 | Firestore rules + indexes | Public content read, per-user entitlements | Current rules deny all. |
| 7 | Signed GCS URLs or CDN for audio | Stream cost/latency | Today every play goes through a 256 MiB Cloud Function. Native playback does many range requests. |
| 8 | Events ingest (phase 3) | "Free tonight near your station" | Scheduled job → Firestore `events`; start with Smithsonian, NPS, Events DC, DC Public Library, BIDs; Ticketmaster covers only large ticketed venues. |

## Pricing and Apple

Digital content unlocked inside an iOS app generally has to be sold through Apple's In-App Purchase, with
Apple's commission, rather than Stripe. Rules and regional link-out exceptions change — read the current App
Store Review Guidelines (3.1.x) before pricing. Product ids proposed: `com.fettink.dcaudiotours.tour.<tourId>`,
`…bundle.starter`, `…allaccess`. Price parity with the web ($3.99 / $6.99 / $19.99) is a business call.

## Data fixes the export surfaced

- `songbyrd` stop: text vs. coordinate disagree (see README).
- Coordinates are geocoded and unreviewed (`location.reviewed == false`). A one-time human pass over the ~116
  unique stops (and 35 station exits) would let the app trust them for turn-by-turn.
