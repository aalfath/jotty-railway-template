# Changelog

## 1.30.0 (2026-11-23)

First release of the Railway template.

- Jotty 1.30.0, `ghcr.io/fccview/jotty:1.30.0@sha256:4face8fd1049d1ec3813f3da949d69fb68703f0f8421902a7a2de8ba3f1d61a6`.
- Admin account created on the first boot from `ADMIN_USERNAME` / generated `ADMIN_PASSWORD`.
- `/app/data` on a Railway volume; `/app/config` kept on the same volume.
- Health check `/api/health`; thread and heap limits for 0.5 GB services.
