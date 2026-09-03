#!/usr/bin/env bash
# Zero Count V2 — staging deploy (E4.3).
# Builds the API image, starts the staging stack, waits for Flyway
# migrations + health, and verifies TLS end to end.
#
# Prereqs on the host: docker + compose plugin, DNS for API_DOMAIN -> host,
# ports 80/443 open, and a filled .env next to this script.

set -euo pipefail
cd "$(dirname "$0")"

COMPOSE_FILE="docker-compose.staging.yml"

fail() { echo "DEPLOY FAILED: $*" >&2; exit 1; }

[ -f .env ] || fail ".env missing — cp .env.example .env and fill in real values"

# shellcheck disable=SC2046
export $(grep -v '^\s*#' .env | grep -v '^\s*$' | xargs)

[ -n "${API_DOMAIN:-}" ] || fail "API_DOMAIN not set in .env"
[ -n "${JWT_SECRET:-}" ] || fail "JWT_SECRET not set in .env"
[ "${#JWT_SECRET}" -ge 32 ] || fail "JWT_SECRET must be >= 32 bytes"
[[ "${DB_PASSWORD:-}" != *__generate_me__* ]] || fail "DB_PASSWORD still a placeholder"
[[ "${JWT_SECRET}" != *__generate_me__* ]] || fail "JWT_SECRET still a placeholder"
[[ "${API_DOMAIN}" != *example.com ]] || fail "API_DOMAIN still a placeholder"

echo "==> Building API image"
docker compose -f "$COMPOSE_FILE" build api

echo "==> Starting stack"
docker compose -f "$COMPOSE_FILE" up -d

echo "==> Waiting for API health (migrations run on boot)"
for i in $(seq 1 60); do
  status="$(docker compose -f "$COMPOSE_FILE" exec -T api \
    wget -qO- http://localhost:8080/actuator/health 2>/dev/null || true)"
  if echo "$status" | grep -q '"UP"'; then
    echo "    API healthy after ${i}0s"
    break
  fi
  [ "$i" -eq 60 ] && fail "API did not become healthy in time"
  sleep 10
done

echo "==> Verifying TLS via https://${API_DOMAIN}"
code="$(curl -s -o /dev/null -w '%{http_code}' "https://${API_DOMAIN}/actuator/health" || true)"
[ "$code" = "200" ] || fail "TLS health check returned HTTP ${code}"

echo "==> Deploy OK — https://${API_DOMAIN} is serving the staging API"
docker compose -f "$COMPOSE_FILE" ps
