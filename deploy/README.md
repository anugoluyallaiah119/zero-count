# Zero Count V2 — staging deployment (E4.3)

One-command deploy of the backend stack (API + Postgres + Redis) behind
Caddy with automatic Let's Encrypt TLS.

## Host prerequisites

- Linux host with Docker Engine + the Compose plugin
- DNS A/AAAA record for your API domain pointing at the host
- Inbound TCP 80 and 443 open (ACME challenges + HTTPS)

## First-time setup

```bash
cd deploy/staging
cp .env.example .env
# Edit .env:
#   API_DOMAIN   — e.g. api.staging.zerocount.gg
#   DB_PASSWORD  — openssl rand -base64 48
#   JWT_SECRET   — openssl rand -base64 48   (>= 32 bytes, unique per env)
chmod +x deploy.sh
./deploy.sh
```

`deploy.sh` refuses to run with placeholder secrets, builds the API image,
starts the stack (Flyway migrations run on boot), waits for
`/actuator/health`, then verifies the public `https://$API_DOMAIN`
endpoint answers 200 over TLS.

## Secrets policy (standards §3)

- Secrets live ONLY in the host's `.env` (gitignored) — never in the repo,
  images, or compose files.
- `JWT_SECRET` is per-environment; staging and prod must differ.
- Staging defaults to the fixed-code OTP provider so QA can log in without
  SMS costs. To rehearse the production auth path, set
  `AUTH_PROVIDER=firebase` and `FIREBASE_PROJECT_ID` in `.env`.

## Operations

```bash
docker compose -f docker-compose.staging.yml logs -f api     # API logs
docker compose -f docker-compose.staging.yml ps              # status
./deploy.sh                                                  # redeploy
```

Caddy renews certificates automatically (state in the `caddydata` volume).
Data persists across redeploys in the `pgdata`/`redisdata` volumes.
