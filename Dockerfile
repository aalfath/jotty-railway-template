# Jotty (https://github.com/fccview/jotty), official image pinned by version and digest.
FROM ghcr.io/fccview/jotty:1.30.0@sha256:4face8fd1049d1ec3813f3da949d69fb68703f0f8421902a7a2de8ba3f1d61a6

ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000

# tini as PID 1: Node runs as its child, so a crash or kill exits non-zero
# and Railway's ON_FAILURE policy restarts the service.
RUN apk add --no-cache tini

# Keep the image's default config so the start script can seed the volume with it.
RUN cp -a /app/config /app/config.dist

COPY --chmod=755 railway-start.sh /usr/local/bin/railway-start.sh
COPY --chmod=644 seed-admin.js /usr/local/lib/jotty-seed-admin.js

EXPOSE 3000
ENTRYPOINT ["/sbin/tini", "-g", "--", "/usr/local/bin/railway-start.sh"]
CMD ["node", "server.js"]
