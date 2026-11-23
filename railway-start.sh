#!/bin/sh
# Railway wrapper for Jotty: volume permissions, persistent config, first-boot admin.
set -eu

DATA=/app/data
export PORT="${PORT:-3000}"
# Listen on IPv4 and IPv6 (Railway's private network is IPv6).
export HOSTNAME="::"
export HTTPS="${HTTPS:-true}"
if [ -z "${APP_URL:-}" ] && [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  export APP_URL="https://${RAILWAY_PUBLIC_DOMAIN}"
fi
export INTERNAL_API_URL="${INTERNAL_API_URL:-http://localhost:${PORT}}"
export PUID="${PUID:-1000}" PGID="${PGID:-1000}"

mkdir -p "$DATA/users" "$DATA/checklists" "$DATA/notes"

# Themes, custom CSS and emoji overrides live in /app/config upstream.
# Keep them on the volume (one volume per Railway service).
mkdir -p "$DATA/.config"
for f in /app/config.dist/* /app/config.dist/.[!.]*; do
  [ -e "$f" ] || continue
  [ -e "$DATA/.config/$(basename "$f")" ] || cp -a "$f" "$DATA/.config/"
done
if [ ! -L /app/config ]; then
  rm -r /app/config
  ln -s "$DATA/.config" /app/config
fi

# First boot: create the admin from ADMIN_USERNAME / ADMIN_PASSWORD so the
# public setup page is never open to the first visitor.
node /usr/local/lib/jotty-seed-admin.js

# Railway mounts volumes as root; Jotty runs as uid 1000.
if [ "$(id -u)" = "0" ]; then
  find "$DATA" \( ! -user "$PUID" -o ! -group "$PGID" \) -exec chown -h "$PUID:$PGID" {} + 2>/dev/null || true
  chown -h "$PUID:$PGID" /app/config 2>/dev/null || true
fi

# Upstream entrypoint applies runtime patches and drops to PUID:PGID.
# Node exits non-zero on a crash, so Railway's ON_FAILURE restart applies.
exec /usr/local/bin/docker-entrypoint.sh "$@"
