# Live Target

## Railway

- Project: `quicksilver-wp`
- Project ID: `9680e4f9-863d-4987-92f5-bcb2d643331a`
- Environment: `production`
- Public WordPress URL: https://wordpress-production-49a8.up.railway.app

## Services

- `WordPress`
  - Source image: `wordpress`
  - Persistent volume: `wordpress-volume`
  - Mount path: `/var/www/html`

- `mariadb`
  - Source image: `mariadb:latest`
  - Persistent volume: `mariadb-volume`
  - Mount path: `/var/lib/mysql`

## Current Boundary

This repo owns source-controlled rebuild work. The Railway WordPress database owns live content state until we add explicit export/import scripts.
