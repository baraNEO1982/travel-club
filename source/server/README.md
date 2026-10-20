# Production: marshrutclub.ru

Since 20 October 2026 the authoritative database and private photos are on the
Timeweb server. Cloudflare D1/KV are a frozen migration backup; do not deploy
`wrangler.club.jsonc` to production again (it would restore the obsolete database).
The old address uses `wrangler.migration.jsonc` to forward API requests and
redirect browser visits, preserving old invitations and existing iPhone builds.

## Runtime

Node 24.19.0, SQLite, nginx, systemd. Application: `/opt/marshrutclub`.
Private data: `/var/lib/marshrutclub/club.sqlite` and `photos/`.
The service binds only to `127.0.0.1:3000`. nginx provides HTTPS and overwrites
X-Real-IP. Certbot manages renewal. Keep the data directory outside the web root.

Build the worker bundle with esbuild (entry `worker/club.ts`, Node platform, ESM,
output `server/club.mjs`), and run `npm run build:web`.
Deploy only `server/` and `dist-web/`; never overwrite live data during code updates.
Restart `marshrutclub.service` after deployment. Run `node server/check.mjs` locally.

The checked-in nginx file is the initial HTTP configuration. The production file
has been updated by Certbot: do not overwrite it with the initial configuration.

## Backup and recovery

Final migration snapshot was verified with SQLite integrity_check and all six
private JPEG files. The owner's local `backups/` directory contains the SQL,
SQLite and photo copies, separately from this repository. SSH credentials also
remain outside the repository.

For future backups use SQLite's online backup API (or stop the service first),
and copy the photos consistently with the database. A raw copy of an active
SQLite database can omit data from its WAL. Do not restore the frozen Cloudflare
snapshot over newer Timeweb data.

Brevo is still unconfigured: email recovery remains disabled until configured.
