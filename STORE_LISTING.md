# Cargo Motives — Store Listing (draft)

Phase 10 launch-prep deliverable. Copy is ready to paste into the Google Play Console / App Store Connect listing forms; screenshots, the signed release build, and a real Play Console / App Store Connect account still need to be produced separately — see "Still needed before submission" below.

## App name
Cargo Motives

## Short description (Play Store, max 80 chars)
Post or bid on container jobs, track them live, get paid — Tanzania B2B logistics.

## Subtitle (App Store, max 30 chars)
B2B Container Logistics

## Full description

Cargo Motives connects businesses that need to move a shipping container with verified transporter companies across Tanzania — post a job or place a bid, track the truck live, and settle up, all in one app.

**For Customers**
- Post a container job in minutes: pickup, drop-off, container type and size, and your preferred pickup window.
- Receive competing bids from verified transporter companies and pick the one that works for you.
- Track your shipment live on the map once a truck with GPS is en route.
- Confirm delivery with photo proof, or report a problem if something's wrong.
- Message the assigned company directly from the job.

**For Transporter Companies**
- Get verified once, then bid on any open job across the marketplace.
- Manage your fleet: register trucks and drivers, connect GPS tracking, and assign the right truck to each job.
- Track your commission balance and pay it down via mobile money whenever it suits you.
- Upgrade to Featured for a higher daily bid quota, priority placement on your bids, and a fleet-wide live map.

Cargo Motives is built for Tanzania: Swahili and English, TZS pricing, and mobile money payments.

## Keywords (App Store, comma-separated, max 100 chars)
logistics,cargo,container,trucking,shipping,tanzania,freight,transport,b2b,fleet

## Category
Business (primary); Google Play secondary category: Logistics / Transportation, if offered in the target market

## Content rating
No user-generated public content, no violence/mature content. Expect a standard "Everyone"/"3+" rating on both stores; complete each store's own content-rating questionnaire at submission (answers aren't guessable ahead of time, but nothing in the app should trigger a higher rating).

## Privacy policy URL
`https://<production-domain>/legal/privacy` (route already live — see `backend/routes/web.php`; swap in the real production domain once one exists)

## Terms of Service URL
`https://<production-domain>/legal/terms`

## Support contact
- Email: support@cargomotives.co.tz (placeholder — replace with a real monitored inbox before submission)
- The privacy policy page also lists privacy@cargomotives.co.tz for data requests specifically.

## App icon
`mobile/assets/icon/icon.png` — a shipping-container mark in the app's own brand colors (deep teal `#0B4F6C` background, amber `#F2994A` container), generated for this phase and wired into both platforms via `flutter_launcher_icons`. This is a real, deliberate icon, not the Flutter template default — but it was produced programmatically (no image-editing tool was available in this environment), so a proper design pass is still worth commissioning before a real public launch.

## Permissions declared
- **Android**: `INTERNET` only (added this phase — was missing from the release manifest entirely; see README's Phase 10 entry). No camera/location/storage permission is declared because none is currently used: document/photo uploads go through the OS's own file/photo picker (`file_picker`), which doesn't require a declared permission on current Android/iOS; there's no in-app camera capture or foreground location access yet.
- **iOS**: no additional usage-description keys needed for the same reason. Revisit this the moment a real camera-capture flow or Google Maps view is added (`google_maps_flutter` is a dependency but not yet wired to any screen).

## Still needed before submission (not something to fabricate here)
- A real Google Play Console / App Store Connect developer account (Google: one-time fee; Apple: annual fee) — outside this app's scope entirely.
- Real device/simulator screenshots for each required size, taken once there's a build worth screenshotting against a real backend.
- A signed release build (Android: a real upload keystore, not the debug one; iOS: a real distribution certificate/provisioning profile) — none of this exists yet, and generating throwaway signing credentials wouldn't be a meaningful step toward real submission.
- A real, monitored support email replacing the placeholder above.
- A production domain to host the backend (and therefore the privacy/terms URLs) at.
