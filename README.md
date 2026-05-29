# QuickSilver WordPress Rebuild

Source-controlled rebuild workspace for the QuickSilver Construction WordPress site.

The live runtime is a Railway-hosted WordPress install. This repo is the local Codex work surface for theme code, scripts, source assets, and reconstruction notes.

## Engineering Standards

Read these before changing WordPress state or theme source:

- `docs/engineering-standard.md` - top-level rules for fail-fast, Codex-first work.
- `docs/wordpress-boundaries.md` - ownership contract across Git, WordPress, Railway, REST, WP-CLI, media, and wp-admin.
- `docs/theme-standard.md` - custom theme rules anchored to official WordPress docs.
- `docs/ops-and-release.md` - checks, draft flow, publish gate, release verification, and rollback posture.
- `docs/source-media-assets.md` - local public media acquisition rules and manifest.
- `docs/motion-interaction-inventory.md` - source-site motion and interaction rebuild spec.

## Current Target

- WordPress URL: https://wordpress-production-49a8.up.railway.app
- Railway project: `quicksilver-wp`
- Railway environment: `production`
- Local Railway link folder: `C:\Users\owen\OneDrive\Documents\Playground\quicksilver-wp-railway`

## Repo Shape

- `theme/quicksilver-construction/` - source-controlled WordPress theme.
- `Dockerfile.wordpress` - Railway WordPress image layer that adds WP-CLI and bundles the repo theme.
- `docker/wordpress-start.sh` - Railway startup script that syncs the bundled theme into the WordPress volume before Apache starts.
- `content/site-model.json` - canonical target site model for pages, sections, copy, contact data, and asset intent.
- `content/pages/` - REST draft-write payloads; not a second content authority.
- `scripts/` - local checks and packaging helpers.
- `assets/source/` - tracked public/source evidence gathered for the rebuild, including text-capture backups. These files are excluded from Railway deploy context by `.dockerignore`, not by Git ignore.
- `docs/` - operator notes and reconstruction runbooks.

## First Checks

```powershell
.\scripts\check-target.ps1
.\scripts\railway-status.ps1
.\scripts\check-theme-local.ps1
.\scripts\verify-railway-wp-cli.ps1
.\scripts\init-local-env.ps1
.\scripts\test-wp-auth.ps1
.\scripts\wp-inventory.ps1
```

After the checks pass and the target slug/status is confirmed, draft content writes use REST payloads derived from `content/site-model.json`:

```powershell
.\scripts\wp-upsert-page.ps1 -File .\content\pages\home.json
```

Railway WordPress runtime control uses the repo-controlled image and WP-CLI wrapper:

```powershell
.\scripts\deploy-wordpress-control-image.ps1
.\scripts\railway-wp-cli.ps1 core is-installed
.\scripts\verify-railway-wp-cli.ps1
```

`scripts\package-theme.ps1` is the lower-level zip helper called by `scripts\check-theme-local.ps1`; the normal pre-deploy theme gate is `scripts\check-theme-local.ps1`.

Secrets belong in a local `.env` or `.env.local` file only. Do not commit WordPress passwords, application passwords, database credentials, or Railway tokens. The full rule is in `docs/engineering-standard.md`.
