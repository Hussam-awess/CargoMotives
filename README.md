# Cargo Motives

B2B container logistics marketplace for Tanzania — verified transporter companies bid on shipper jobs, with live GPS tracking where available and a 30% platform commission collected via mobile money.

Full specification lives in the sibling `Cargo Motives v4 DOCs` folder (PRD, TRD, AppFlow, UI/UX Brief, Backend Schema, Implementation Plan). This repo implements that spec phase by phase; this README tracks vendor decisions and current build status so either of us can pick the thread back up without re-deriving context.

## Repo layout

```
backend/             Laravel — REST API, Admin (Livewire), Driver Link pages
mobile/               Flutter — Customer + Transporter Company app (Android + iOS)
docker/php/           Dockerfile for the backend's PHP containers (see "Docker" note below)
docker-compose.yml     Postgres+PostGIS, Redis, MinIO, the Laravel app, queue worker, Reverb
.local-services/redis/ Portable Redis-for-Windows build used for local dev on this machine (gitignored — see setup below)
```

## Vendor / technology decisions

| Decision | Choice | Status |
|---|---|---|
| Backend | Laravel 13, PHP 8.3+ | scaffolded |
| Database | PostgreSQL + PostGIS | **running** — installed natively (v18.4 + PostGIS 3.6.2 on this machine; the Docker image targets v16, either works, nothing in the schema is version-specific) |
| Cache/Queue/Broadcast | Redis (via `predis`, not the phpredis extension — works identically whether or not that PHP extension is installed) | **running** — see "Local development setup" |
| Real-time | Laravel Reverb (WebSockets) — used only for live GPS + live bids per TRD §4 | installed |
| Object storage | S3-compatible; MinIO locally, a real bucket in staging/prod | `App\Services\Documents\DocumentStorage` — **working**, but currently backed by the local disk (Docker/MinIO isn't running on this machine — see below); disk-agnostic by design, so switching to S3/MinIO later is a config change, not a code change |
| Auth | Laravel Sanctum (Customer/Company/Admin); a separate short-lived signed token for the Driver Link | installed |
| Mobile | Flutter, one app, role-aware routing (`go_router`) | scaffolded |
| Maps | **Google Maps** | key not yet provisioned — set `GOOGLE_MAPS_API_KEY` |
| Mobile money | **Selcom** | building against sandbox; real merchant credentials needed before go-live |
| First GPS provider | **Wialon** (Phase 6) | not started |
| SMS gateway | **Deferred** — `SMS_DRIVER=log` (writes to the log instead of sending) until a provider is chosen. Leading candidate: Beem Africa. | driver abstraction built (`App\Services\Sms`), no real provider wired yet |
| Error monitoring | Sentry (planned, TRD §10) | not yet added |
| Auth | Phone + OTP, shared by Customer & Transporter Company (PRD §6) | **working** — Sanctum tokens, Redis-backed OTP, rate-limited |
| Admin login | Email + password (`users.password_hash`) | **working** — minimal, ahead of the full Admin tool (Phase 9); bootstrap the first admin with `php artisan admin:create <phone> <email> <password>` |

## Local development setup

**Docker isn't usable on this particular machine** — it's physical hardware without VT-x/AMD-V exposed to Windows, so WSL2 (and therefore Docker Desktop) can't start a VM. `docker-compose.yml` is still there and correct for any machine that *does* support virtualization (a teammate's machine, CI, staging), but local dev here runs Postgres and Redis natively instead. If you're on a machine where Docker works, skip to "Alternative: Docker" below.

### 1. PostgreSQL + PostGIS

Already installed on this machine (PostgreSQL 18.4, via the official EDB installer, with the matching [PostGIS Windows bundle](https://postgis.net/windows_downloads/) installed on top). On a fresh machine:

1. Download PostgreSQL from https://www.postgresql.org/download/windows/ and install it (note the superuser password you set).
2. Download the matching PostGIS bundle for your PostgreSQL major version from https://download.osgeo.org/postgis/windows/ (e.g. `pg18` → `postgis-bundle-pg18x64-setup-*.exe`) and run it.
3. Create the app's role, database, and enable the extension (run as the `postgres` superuser):
   ```sql
   CREATE ROLE cargo_motives LOGIN PASSWORD 'secret';
   CREATE DATABASE cargo_motives OWNER cargo_motives;
   \c cargo_motives
   CREATE EXTENSION IF NOT EXISTS postgis;
   ```
   This matches `backend/.env`'s `DB_USERNAME`/`DB_PASSWORD` already — no `.env` changes needed. The superuser password is never stored in the app config, only used for this one-time setup.

**Note on installers needing elevation:** on this machine, running the Postgres/PostGIS installers (and an MSI-based Redis installer we tried first) from an automated/non-interactive shell failed — Windows couldn't show the UAC consent prompt those installers need. Running them from a normal interactive **Administrator** PowerShell/terminal works fine.

### 2. Redis (portable, no installer)

An MSI-based Redis-compatible service (Memurai) consistently failed to install on this machine even from an elevated terminal — Windows Installer's own SYSTEM-level temp directory was inaccessible, which looks like a machine-specific restriction unrelated to normal admin rights. The workaround: a portable, dependency-free Redis build ([tporadowski/redis](https://github.com/tporadowski/redis/releases), an unofficial but widely-used Windows port) that's just an `.exe` — no installer, no service, no elevation needed.

Already set up in `.local-services/redis/` (gitignored — it's a downloaded third-party binary, not project source). To start it:

```powershell
powershell -File .local-services\start-redis.ps1
```

This is **not a Windows service** — it's a plain foreground process, so it needs to be started again after every reboot or terminal close. Leave that terminal open while working on the backend, or run it in its own background terminal/tab.

### 3. Backend

```bash
cd backend
php artisan migrate
php artisan serve
```

### 4. Verify

```bash
curl http://localhost:8000/api/health
```

Should return `{"status":"ok","checks":{"database":{"ok":true},"redis":{"ok":true}}}`. If either check is `false`, the error message names which dependency is unreachable and why — see `app/Http/Controllers/HealthController.php` for what each failure mode means.

### Alternative: Docker (on a machine that supports virtualization)

```bash
cp .env.example .env
docker compose up -d
docker compose exec app php artisan migrate
curl http://localhost:8000/api/health
```

This also brings up MinIO (S3-compatible storage) and Reverb, which the native setup above doesn't include yet — needed once file uploads (Phase 2+) or WebSockets (Phase 4+) are being tested locally, if this machine's Docker situation doesn't change before then.

### Mobile app

```bash
cd mobile
flutter pub get
flutter run          # or: flutter run -d chrome
```

## Phase status

Tracking the Implementation Plan document's 12 phases. Each phase is built, explained, and verified before the next starts.

- [x] **Phase 0 — Foundations**: Laravel + Flutter scaffolds, Docker Compose, vendor choices documented, `/api/health` endpoint, SMS driver abstraction. Verified end-to-end against a real (natively-installed) Postgres+PostGIS and Redis — not just against sqlite/mocks.
- [x] **Phase 1 — Auth (Customer & Company)**: shared phone/OTP flow (`App\Services\Auth\OtpService`, Redis-backed with attempt lockout + resend cooldown), phone number normalization, Sanctum tokens, rate limiting (`otp-request`/`otp-verify` limiters), Customer profile completion. Flutter: Phone Entry → OTP → Profile Setup screens, `ApiClient`/`AuthRepository`, session persistence. 29 backend tests + 13 Flutter tests passing; walked the full flow live in a browser against the real stack for both roles (Customer → Profile Setup → Customer Home; Transporter Company → Company Home placeholder). Found and fixed two real bugs along the way: a default Laravel guest-redirect that 500'd unauthenticated API requests lacking an `Accept: application/json` header, and an OTP lockout off-by-one.
- [x] **Phase 2 — Company Verification (manual review, anti-duplicate)**: two-section verification submission (`App\Http\Controllers\Company\CompanyVerificationController`), `CompanyDuplicateDetector` (a registration number/TIN/NIDA collision is flagged for Admin, never silently accepted or rejected — deliberately *not* a DB-level unique constraint, since that would make flagging impossible), private document storage with signed URLs (`DocumentStorage`), and a minimal Admin login + review API (list/approve/reject) ahead of the full Admin tool (Phase 9). Flutter: `CompanyHomeGate` routes a Transporter Company session to the verification form, a pending-review screen, or Company Home based on live status — checked fresh on every session, not just after login. 61 backend tests + 22 Flutter tests passing; walked all four states (submit → flagged-duplicate → admin reject → resubmit → admin approve → Company Home) live against the real stack, including a live approve/reject through the Admin API. Found and fixed three real bugs: two mass-assignment gaps where a field silently got dropped because it wasn't in a model's `$fillable` list (`owner_user_id`, then `password_hash` — the latter meant the admin-bootstrap command created unusable accounts, invisible to factory-based tests since factories bypass mass-assignment), and a `setState()` given a closure that returned a `Future` (an easy-to-miss Dart gotcha from an arrow function whose body was an assignment expression).
- [x] **Phase 3 — Trucks & Drivers**: truck registration with independent Admin verification (`App\Http\Controllers\Company\TruckController` — same create-or-resubmit-if-rejected shape as company verification), a driver roster with no verification workflow (drivers are never Admin-reviewed, PRD §5), a reusable `EnsureCompanyApproved` middleware (fleet management only opens up once the company itself is approved — Phase 4's bidding will need this exact check again), and a matching Admin truck-review API. Flutter: a real Company Home shell (bottom nav — Jobs/Fleet/Earnings/Profile, UI/UX Brief §3) with a working Fleet tab (Trucks/Drivers sub-tabs, add/resubmit forms with `file_picker`) and a minimal but real Profile tab (company name + logout). 83 backend tests + 37 Flutter tests passing; walked the full flow live — register two trucks, approve one/reject the other via the Admin API, add a driver, confirm the Fleet tab and Profile tab both render real data end-to-end in a browser.
  - Found and fixed a real bug affecting every phase's models so far, not just this one: Eloquent's `create()` doesn't reflect a migration's DB-level `->default(...)` values on the in-memory model it returns — a freshly-registered truck's `gps_status`/`current_status`/`is_active` were `null` in the live API response despite the DB row being correct. Fixed by declaring `protected $attributes` on `User`, `TransporterCompany`, `Truck`, and `Driver` to mirror their migrations' defaults.
  - Found and fixed a real Flutter/Dio bug before it ever shipped: Dio's default `ListFormat.multi` only brackets a list entry when the entry is a Map/List, not a `MultipartFile` — so uploading multiple truck photos would have silently sent them all under the same bare `photos` field name, and Laravel/PHP keeps only the *last* of several identically-named non-bracketed multipart parts. Fixed with `ListFormat.multiCompatible`; pinned with a regression test since it's the kind of thing a future Dio upgrade or an "innocent" refactor could silently reintroduce.
- [x] **Phase 4 — Job Posting & Bidding**: jobs/bids schema (Backend Schema §2.7) with PostGIS `geography(Point,4326)` pickup/dropoff columns (no Eloquent cast exists for these — written via raw `ST_SetSRID(ST_MakePoint(...))` through a small `GeoPoint` value object, read back via a `withCoordinates()` query scope using `ST_X`/`ST_Y`), a partial unique Postgres index enforcing "one pending bid per company per job" (`WHERE status = 'pending'`, not a plain unique constraint — a company can re-bid after withdrawing or being rejected), and Redis sorted-set rolling-window quotas (`RollingQuotaService`, `BidQuotaService`, `JobPostQuotaService`) for both customer job-posting (5/day standard, 10/day Featured) and company bidding (5/24h standard, 10/15h Featured) — deliberately not fixed-window `INCR`+`EXPIRE`, which lets a burst empty and refill a quota right at the window boundary. Bid acceptance (`BidController::accept`) runs in a DB transaction with `lockForUpdate()`, assigning the job and rejecting every other pending bid atomically. First real use of Reverb: `BidPlaced` broadcasts on a private `job.{jobId}` channel, authorized by a class-based `App\Broadcasting\JobChannel` (not an inline closure) so channel authorization is directly unit-testable without an HTTP round trip. Flutter: Customer Post-a-Job form + Job Detail screen with a live-updating bid list (Featured bids pinned first) via a hand-rolled minimal Pusher-protocol WebSocket client (`JobBidChannel`, using `web_socket_channel` — the obvious `pusher_channels_flutter` package turned out to hardcode Pusher's own cloud infrastructure host with no way to point it at a self-hosted Reverb server) and Accept Bid; Company Open/My Bids/Active job feeds (tabbed, mirroring the Fleet tab's Trucks/Drivers split) and a bid-placement form with live quota display. 132 backend tests + 55 Flutter tests passing. Walked the full flow live against the real stack (Postgres, Redis, a running Reverb server, and a queue worker — `BidPlaced` is a *queued* broadcast, so nothing reaches a socket without one): posted a job as a customer, subscribed to its private channel with a real WebSocket client, placed a bid as an approved company, and watched the `bid.placed` event arrive over the open socket in real time before accepting the bid and confirming the job transitioned to `assigned` with `agreed_price` set; also confirmed quota counters decrement correctly and a duplicate-pending-bid attempt is rejected with 422.
  - Found and fixed a real test-infrastructure gap, not just a Phase 4 edge case: PostGIS raw SQL (`::geography`, `ST_MakePoint`) cannot run against SQLite at all, and PostGIS is now core to the schema — so `phpunit.xml` was switched from an in-memory SQLite DB to a dedicated real Postgres database (`cargo_motives_test`), with a dedicated Redis logical DB (`REDIS_DB=2`) alongside it so quota tests can't leak state into (or read stale state from) dev Redis.
  - Found and fixed a subtle Redis bug during that same isolation work: `Redis::keys('prefix:*')` returns keys *with* Laravel's configured key prefix already applied, so passing those results straight to `Redis::del()` applies the prefix a second time and silently deletes nothing — quota state was leaking between test runs (and into dev Redis) until this was caught via `tinker`.
  - Found and fixed a broadcast-channel-authorization testability dead end: `NullBroadcaster::auth()` (active under `BROADCAST_CONNECTION=null` in tests) never invokes registered channel-authorization callbacks at all, and switching a test to the real Reverb driver hit deeper signing complexity. Refactored the inline channel closure into `App\Broadcasting\JobChannel` so its `join()` logic could be unit-tested directly, sidestepping the broadcaster entirely.
- [ ] Phase 5 — Job Assignment, Driver Link & Proof of Delivery
- [ ] Phase 6 — GPS: Wialon, end to end
- [ ] Phase 7 — Commission Ledger & Mobile Money (Selcom)
- [ ] Phase 8 — Featured Tier & Messaging
- [ ] Phase 9 — Admin Tool
- [ ] Phase 10 — Hardening & Launch Prep
- [ ] Phase 11 — Launch & Learn
