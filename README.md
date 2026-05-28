# QuickSilver WordPress Rebuild

Source-controlled rebuild workspace for the QuickSilver Construction WordPress site.

The live runtime is a Railway-hosted WordPress install. This repo is the local Codex work surface for theme code, scripts, source assets, and reconstruction notes.

## Current Target

- WordPress URL: https://wordpress-production-49a8.up.railway.app
- Railway project: `quicksilver-wp`
- Railway environment: `production`
- Local Railway link folder: `C:\Users\owen\OneDrive\Documents\Playground\quicksilver-wp-railway`

## Repo Shape

- `theme/quicksilver-construction/` - source-controlled WordPress theme.
- `scripts/` - local checks and packaging helpers.
- `assets/source/` - public/source assets gathered for the rebuild.
- `docs/` - operator notes and reconstruction runbooks.

## First Commands

```powershell
.\scripts\check-target.ps1
.\scripts\railway-status.ps1
.\scripts\package-theme.ps1
.\scripts\init-local-env.ps1
.\scripts\test-wp-auth.ps1
.\scripts\wp-inventory.ps1
.\scripts\wp-upsert-page.ps1 -File .\content\pages\home.json
```

Secrets belong in a local `.env` or `.env.local` file only. Do not commit WordPress passwords, application passwords, database credentials, or Railway tokens.
