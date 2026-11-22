# Firestore schema (iOS + web)

Same Firebase project as the web app (`whatsupmetrodc`). **Phase 1 does not use Firestore** — content is
bundled. This is the contract for phase 2, and it mirrors the bundled JSON exactly so the app swaps its loader,
not its models.

## Content (public read, server-only write)

```
catalog/meta                          { schemaVersion, generatedAt, freeTourId, languages[] }

tours/{tourId}                        { kind: "themed"|"area", isFree, title{lang}, tagline{lang}, marketing{lang}?,
                                        accentLine?, stopCount, route? { details, metricsEstimated, totalMeters,
                                        totalSeconds, legs[{from,to,meters,seconds,minutes}] }, version }

tours/{tourId}/stops/{stopId}         { order, contentKey, station, lines[], exit, walkMin, name{lang}, duration{lang},
                                        stationLocation { lat, lon, geohash },
                                        location { lat, lon, geohash, source, reviewed },
                                        audioKeys[], subStops[{id, name{lang}}] }

i18n/{lang}/stops/{tourId}__{stopId}  { narration, tips, subStops[{id,name,directions,narration,tips}] }
                                       // doc id = contentKey with "/" replaced by "__"
```

**Why a separate `i18n/{lang}` tree:** a stop with sub-stops is ~63 KB across 8 languages but ~6 KB in one.
The app downloads only the listener's language (≈330–510 KB for the whole catalog) and Firestore's offline
cache keeps it for the commute. Docs stay far below the 1 MiB limit.

**Stop ids are not globally unique in meaning:** `tours/{a}/stops/x` and `tours/{b}/stops/x` can differ.
`contentKey` (`<ownerTourId>/<stopId>`) is the key into `i18n`; area tours point at their owner themed tour so
their text isn't duplicated.

## Entitlements (per user, server-only write)

```
users/{uid}                            { createdAt, language }
users/{uid}/entitlements/{id}          { source: "appstore"|"stripe", productId, tourIds[], allAccess,
                                         purchasedAt, expiresAt?, revokedAt?, originalTransactionId? | stripeSessionId? }
```

`Entitlements` in TourKit = union of `tourIds` across non-revoked docs, plus `allAccess`. Both the Stripe webhook
(web) and App Store Server Notifications V2 (iOS) write here, so a purchase on either platform unlocks both.

The existing web collection `tourPurchases/{stripeSessionId}` (email-keyed) stays as is.

> **Linking web purchases to an Apple account:** don't match on email. Sign in with Apple can return a private
> relay address, so the address won't match what the buyer typed at Stripe checkout. Use an emailed one-time
> code ("Restore web purchases") that proves control of the checkout email.

## Events (phase 3)

```
events/{eventId}   { source, title, venue, location{lat,lon,geohash}, nearestStation, startsAt, endsAt,
                     isFree, category, url, updatedAt }
```

Query "near me, tonight" with geohash prefix ranges (`>=` / `<=` on `location.geohash`) plus `startsAt`.
Firestore has no native geo-queries; compute the 9 neighbouring cells of a precision-5 geohash on the client
(`Coordinate.geohash(precision:)` exists in TourKit).

## Security rules (sketch)

```
match /catalog/{d}            { allow read: if true; allow write: if false; }
match /tours/{t=**}           { allow read: if true; allow write: if false; }
match /i18n/{l=**}            { allow read: if true; allow write: if false; }
match /events/{e}             { allow read: if true; allow write: if false; }
match /users/{uid}            { allow read, update: if request.auth.uid == uid && onlyAllowedFields(); }
match /users/{uid}/entitlements/{e} { allow read: if request.auth.uid == uid; allow write: if false; }
```

The web repo's current `firestore.rules` denies everything (server-admin only); these rules replace it.
Entitlement *enforcement* stays on the server (audio tokens) — never trust the client's own entitlement set.
