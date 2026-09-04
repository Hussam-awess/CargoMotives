# Cargo Motives

B2B container logistics marketplace for Tanzania — verified transporter companies bid on shipper jobs, with live GPS tracking where available and a 30% platform commission collected via mobile money.

Full specification lives in the sibling `Cargo Motives v4 DOCs` folder (PRD, TRD, AppFlow, UI/UX Brief, Backend Schema, Implementation Plan). This repo implements that spec phase by phase; this README tracks vendor decisions and current build status so either of us can pick the thread back up without re-deriving context.

## Repo layout

```
backend/            Laravel — REST API, Admin (Livewire), Driver Link pages
mobile/              Flutter — Customer + Transporter Company app (Android + iOS)
docker/php/          Dockerfile for the backend's PHP containers
docker-compose.yml   Postgres+PostGIS, Redis, MinIO, the Laravel app, queue worker, Reverb
```

## Vendor / technology decisions

| Decision | Choice | Status |
|---|---|---|
| Backend | Laravel 13, PHP 8.3+ | scaffolded |
| Database | PostgreSQL 16 + PostGIS | configured, not yet running (see below) |
| Cache/Queue/Broadcast | Redis (via `predis`, not the phpredis extension — works identically whether or not that PHP extension is installed) | configured |
| Real-time | Laravel Reverb (WebSockets) — used only for live GPS + live bids per TRD §4 | installed |
| Object storage | S3-compatible; MinIO locally, a real bucket in staging/prod | configured |
| Auth | Laravel Sanctum (Customer/Company/Admin); a separate short-lived signed token for the Driver Link | installed |
| Mobile | Flutter, one app, role-aware routing (`go_router`) | scaffolded |
| Maps | **Google Maps** | key not yet provisioned — set `GOOGLE_MAPS_API_KEY` |
| Mobile money | **Selcom** | building against sandbox; real merchant credentials needed before go-live |
| First GPS provider | **Wialon** (Phase 6) | not started |
| SMS gateway | **Deferred** — `SMS_DRIVER=log` (writes to the log instead of sending) until a provider is chosen. Leading candidate: Beem Africa. | driver abstraction built (`App\Services\Sms`), no real provider wired yet |
| Error monitoring | Sentry (planned, TRD §10) | not yet added |

## Local development setup

### 1. Docker Desktop (required)

This machine didn't have WSL2 installed, which Docker Desktop on Windows requires. From an **elevated** PowerShell/Terminal:

```powershell
wsl --install
```

Reboot when prompted, then install [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/) and make sure it's using the WSL2 backend (default on a fresh install).

### 2. Bring up the stack

```bash
cp .env.example .env
docker compose up -d
```

This starts Postgres+PostGIS, Redis, MinIO (with the app's bucket auto-created), the Laravel app (`http://localhost:8000`), a queue worker, and Reverb (`ws://localhost:8080`).

### 3. Backend — first-time setup inside the container

```bash
docker compose exec app php artisan migrate
```

(`backend/.env` already points at the compose services' hostnames — `postgres`, `redis` — when run this way.)

### 4. Verify

```bash
curl http://localhost:8000/api/health
```

Should return `{"status":"ok","checks":{"database":{"ok":true},"redis":{"ok":true}}}`. If either check is `false`, the error message names which dependency is unreachable and why — see `app/Http/Controllers/HealthController.php` for what each failure mode means.

### Running the backend without Docker

Also works standalone if you have PHP 8.3+, PostgreSQL 16+ with PostGIS, and Redis running locally — set `backend/.env`'s `DB_HOST`/`REDIS_HOST` to `127.0.0.1` (already the default) and run `php artisan serve` from `backend/`.

### Mobile app

```bash
cd mobile
flutter pub get
flutter run          # or: flutter run -d chrome
```

## Phase status

Tracking the Implementation Plan document's 12 phases. Each phase is built, explained, and verified before the next starts.

- [x] **Phase 0 — Foundations**: Laravel + Flutter scaffolds, Docker Compose, vendor choices documented, `/api/health` endpoint, SMS driver abstraction.
- [ ] Phase 1 — Auth (Customer & Company), rate-limited
- [ ] Phase 2 — Company Verification (manual review, anti-duplicate)
- [ ] Phase 3 — Trucks & Drivers
- [ ] Phase 4 — Job Posting & Bidding
- [ ] Phase 5 — Job Assignment, Driver Link & Proof of Delivery
- [ ] Phase 6 — GPS: Wialon, end to end
- [ ] Phase 7 — Commission Ledger & Mobile Money (Selcom)
- [ ] Phase 8 — Featured Tier & Messaging
- [ ] Phase 9 — Admin Tool
- [ ] Phase 10 — Hardening & Launch Prep
- [ ] Phase 11 — Launch & Learn
