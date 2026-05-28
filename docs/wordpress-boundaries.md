# WordPress Boundaries

This document defines who owns each part of the QuickSilver WordPress rebuild. Boundary clarity is the main defense against clunky WordPress drift.

## Ownership Map

| Surface | Owner | Repo Rule |
| --- | --- | --- |
| Theme source | Git | Edit under `theme/quicksilver-construction/`; package from repo source. |
| Scripts | Git | Source-control repeatable operations under `scripts/`. |
| Docs | Git | Keep standards in the four governance docs; keep notes factual. |
| Target content model | Git | `content/site-model.json` owns canonical page intent, section order, business copy, contact details, and asset intent. |
| REST draft payloads | Git | `content/pages/*.json` stores write inputs for REST scripts; payloads must derive from the target model or be explicitly marked provisional evidence. |
| Source assets | Git | Store public/source assets under `assets/source/` with provenance where known. |
| Live posts/pages | WordPress DB | Inspect content through REST scripts; use the scripted WP-CLI wrapper for runtime/admin state that REST does not own. |
| Post IDs/revisions/options | WordPress DB | Treat as runtime state, not portable source. |
| Uploaded media records | WordPress DB | Upload through a scripted path once that path exists. |
| Runtime services | Railway | Inspect through Railway CLI from the linked Railway folder. |
| Runtime files/volumes | Railway volumes | Do not treat live volume edits as source. |

## Current Runtime

- Railway project: `quicksilver-wp`
- Railway project ID: `9680e4f9-863d-4987-92f5-bcb2d643331a`
- Environment: `production`
- Public URL: `https://wordpress-production-49a8.up.railway.app`
- WordPress service: `WordPress`
- MariaDB service: `mariadb`
- WordPress volume mount: `/var/www/html`
- MariaDB volume mount: `/var/lib/mysql`

`docs/live-target.md` records current live target facts. This document records the ownership rule.

## Control Surfaces

### REST

REST is the current content-control path for Codex. It owns authentication checks, inventory, and draft page writes through scripts.

Current scripts:

- `scripts/test-wp-auth.ps1`
- `scripts/wp-inventory.ps1`
- `scripts/wp-rest.ps1`
- `scripts/wp-upsert-page.ps1`

REST scripts must require `WORDPRESS_BASE_URL`, `WORDPRESS_USERNAME`, and `WORDPRESS_APPLICATION_PASSWORD` from local env. For this hosted site, `WORDPRESS_BASE_URL` must use `https://` because application passwords are sent through HTTP Basic Authentication.

### WP-CLI

WP-CLI is the terminal-first admin path for theme, plugin, export, import, option, and user operations that are not better handled through REST.

Current owner:

- `Dockerfile.wordpress` installs WP-CLI into the Railway WordPress image.
- `scripts\deploy-wordpress-control-image.ps1` deploys that image to the existing `WordPress` service.
- `scripts\railway-wp-cli.ps1` is the only normal local wrapper for remote WP-CLI execution.
- `scripts\verify-railway-wp-cli.ps1` verifies WP-CLI, WordPress core install state, site URL, active theme, and bundled QuickSilver theme visibility.
- `scripts\activate-railway-theme.ps1` is the explicit activation path for the bundled QuickSilver theme.

WP-CLI commands must run through repo scripts or a named runbook step. Do not SSH into the container and run unmanaged WordPress mutation commands by hand.

### Railway CLI

Railway CLI is the runtime inspection path for services, volumes, deployment state, logs, and restarts.

Use the linked Railway folder:

```powershell
C:\Users\owen\OneDrive\Documents\Playground\quicksilver-wp-railway
```

Do not expose database TCP access unless a task explicitly requires it and the operation has a backup/export plan.

The `WordPress` service uses a repo-controlled Dockerfile deployment for Codex control. The image is based on the previously deployed official WordPress image digest and adds WP-CLI plus a bundled copy of `theme/quicksilver-construction/`. The persistent WordPress volume remains the live runtime file store at `/var/www/html`.

### wp-admin

wp-admin is for bootstrap, account/application-password creation, emergency inspection, and final visual confirmation when scripts do not expose a WordPress feature yet.

wp-admin is not the normal authoring surface for this project. A repeated wp-admin action must become a script or a runbook step.

### Media

Media has two states:

- Source asset: a file and provenance record under `assets/source/`.
- WordPress media item: an uploaded runtime record in the WordPress DB and uploads volume.

Do not assume source assets and uploaded media are synchronized until a media upload/inventory script proves it.

## Prohibited Boundary Crossings

- Do not edit live theme files and then treat the result as source.
- Do not sync theme files outside `scripts\deploy-wordpress-control-image.ps1`.
- Do not activate the QuickSilver theme outside `scripts\activate-railway-theme.ps1`.
- Do not change WordPress options through wp-admin except for an explicit bootstrap/emergency reason; record the reason and add a script or runbook owner before the action becomes normal process.
- Do not overwrite database state without an explicit export/backup and rollback procedure.
- Do not install source-site plugins because they appeared on the old public site.
- Do not create a second content-writing path without retiring or documenting the first path as inactive.
- Do not add Railway mutations to a docs or theme-source task.
