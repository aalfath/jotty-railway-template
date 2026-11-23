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

# Railway shows the host's CPUs (32+) inside a 1 vCPU service: keep image and
# libuv thread pools small, and size the Node heap to the memory limit.
export VIPS_CONCURRENCY="${VIPS_CONCURRENCY:-2}"
export UV_THREADPOOL_SIZE="${UV_THREADPOOL_SIZE:-4}"
export MALLOC_ARENA_MAX="${MALLOC_ARENA_MAX:-2}"
if [ -z "${NODE_OPTIONS:-}" ]; then
  lim=$(cat /sys/fs/cgroup/memory.max 2>/dev/null || echo max)
  case "$lim" in
    ''|max) ;;
    *) heap=$((lim / 1048576 * 70 / 100))
       [ "$heap" -lt 192 ] && heap=192
       export NODE_OPTIONS="--max-old-space-size=$heap" ;;
  esac
fi

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
# Jotty runs as a child of this script (not as PID 1), so a crash or a kill
# ends the container with a non-zero code and Railway's ON_FAILURE policy
# restarts it. A stop request (SIGTERM/SIGINT) is passed on and exits 0.
stopping=0
on_stop() { stopping=1; [ -n "${child:-}" ] && kill -TERM "$child" 2>/dev/null; }
trap on_stop TERM INT
/usr/local/bin/docker-entrypoint.sh "$@" &
child=$!
set +e
rc=0
while kill -0 "$child" 2>/dev/null; do
  wait "$child"
  rc=$?
done
if [ "$stopping" = 1 ]; then exit 0; fi
[ "$rc" -eq 0 ] && rc=1
echo "[railway] Jotty exited unexpectedly (code $rc); exiting so Railway restarts it" >&2
exit "$rc"
