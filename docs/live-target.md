# Live Target

Current runtime facts live here. Ownership rules live in `docs/wordpress-boundaries.md`; operational checks live in `docs/ops-and-release.md`.

## Railway

- Project: `quicksilver-wp`
- Project ID: `9680e4f9-863d-4987-92f5-bcb2d643331a`
- Environment: `production`
- Public WordPress URL: https://wordpress-production-49a8.up.railway.app

## Services

- `WordPress`
  - Source image: repo-controlled Railway Dockerfile based on `wordpress@sha256:d32999a243ee5051babf8580ff22e7254129fe2f209f3d10aacdc81fdcd33959`
  - WP-CLI: installed in the image as `/usr/local/bin/wp`
  - Bundled theme sync: `theme/quicksilver-construction/` is copied into `/var/www/html/wp-content/themes/quicksilver-construction` during container startup
  - Persistent volume: `wordpress-volume`
  - Mount path: `/var/www/html`

- `mariadb`
  - Source image: `mariadb:latest`
  - Persistent volume: `mariadb-volume`
  - Mount path: `/var/lib/mysql`

## Boundary

Use `docs/wordpress-boundaries.md` for the ownership contract.
