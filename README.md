[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/jotty-1?utm_medium=integration&utm_source=button&utm_campaign=jotty)

# Jotty on Railway

One-click Railway template for [Jotty](https://github.com/fccview/jotty) (jotty·page), a lightweight self-hosted app for checklists, kanban boards and markdown notes that keeps everything as plain files.

- **Version:** Jotty 1.30.0, official image `ghcr.io/fccview/jotty:1.30.0`, pinned by digest in the [`Dockerfile`](Dockerfile).
- **Services:** one `jotty` service built from this repo, with a Railway volume at `/app/data`. No database: Jotty stores users, notes, checklists, uploads and settings as files.
- **Admin:** created on the first boot from `ADMIN_USERNAME` and a generated `ADMIN_PASSWORD`, so the public setup page is never open to the first visitor.
- **Memory:** runs in Railway's Free plan limit (0.5 GB RAM, 1 vCPU); about 120–200 MB in use.

## Variables

| Variable | Default | What it does |
|---|---|---|
| `ADMIN_USERNAME` | `admin` | Username of the admin account created on the first boot. |
| `ADMIN_PASSWORD` | generated (`${{secret(24,…)}}`) | Password of that admin. Read it in the service's **Variables** tab. Used only on the first boot: change it later in Jotty's settings. |
| `APP_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public address. Sessions and SSO redirects use it. Change it if you add a custom domain. |
| `PORT` | `3000` | Port Jotty listens on; the Railway domain points at it. |

There are no prompts: everything has a working default.

Optional settings from [upstream's list](https://github.com/fccview/jotty/blob/main/howto/ENV-VARIABLES.md) can be added as service variables, for example `AUTH_MODE=oidc` with `OIDC_ISSUER`, `OIDC_CLIENT_ID` and `OIDC_CLIENT_SECRET` (callback `https://YOUR-DOMAIN/api/oidc/callback`), `SSO_FALLBACK_LOCAL=yes`, `SERVE_PUBLIC_IMAGES=yes`, `DEFAULT_LOCALE`, or `STOP_CHECK_UPDATES=yes`.

## What the wrapper does

[`railway-start.sh`](railway-start.sh) runs before Jotty's own entrypoint:

1. Listens on IPv4 and IPv6 and sets `HTTPS=true` (secure cookies) and `APP_URL` from the Railway domain.
2. Moves Jotty's `/app/config` (themes, custom CSS, emoji overrides) onto the volume at `/app/data/.config`, because a Railway service has one volume.
3. Creates the admin with [`seed-admin.js`](seed-admin.js) when no user exists yet, in the same format as Jotty's setup form. With users present it changes nothing. With no `ADMIN_PASSWORD` it exits non-zero instead of leaving the setup page open (unless `AUTH_MODE=oidc`).
4. Gives the volume to uid 1000 and starts Jotty as that user.
5. Caps libvips and libuv threads and sizes the Node heap to the service's memory limit, so the app stays inside 0.5 GB.

Health check: `/api/health`. Restart policy: on failure. Jotty runs as a child of the start script, so if it crashes or is killed the container exits non-zero and Railway restarts it.

## Updates

Railway tells everyone who deployed this template when a new version lands on `main`; you choose when to apply it. Each version bump pins a new upstream release by digest and gets an entry in [`CHANGELOG.md`](CHANGELOG.md), with breaking changes first. Your data stays on the volume across updates.

Back up the volume (Railway volume backups, or Jotty's export) before major upgrades.

## Licence

Jotty is AGPL-3.0, by [fccview](https://github.com/fccview). This repo only holds the Railway packaging.
