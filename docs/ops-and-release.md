# Ops And Release

This runbook covers current Codex-first operations for the Railway-hosted QuickSilver WordPress install.

## Preconditions

- Work from `C:\Users\owen\OneDrive\Documents\Playground\quicksilver-wp-rebuild`.
- Keep secrets in `.env.local`; confirm `.env.local` is ignored.
- Keep Railway inspection in `C:\Users\owen\OneDrive\Documents\Playground\quicksilver-wp-railway`.
- Confirm the target before writing.

## Standard Checks

Run these before WordPress writes:

```powershell
.\scripts\test-wp-auth.ps1
.\scripts\wp-inventory.ps1
.\scripts\check-target.ps1
```

Run this before Railway operations:

```powershell
.\scripts\railway-status.ps1
```

Run this before theme package review:

```powershell
.\scripts\package-theme.ps1
```

## Content Draft Flow

1. Author or update a source file under `content/pages/`.
2. Run `.\scripts\test-wp-auth.ps1`.
3. Run `.\scripts\wp-inventory.ps1` and confirm the target slug/status.
4. Run `.\scripts\wp-upsert-page.ps1 -File .\content\pages\<page>.json`.
5. Confirm the returned page ID, slug, status, and link.
6. Open the draft preview or authenticated URL in the browser when visual verification is required.

`wp-upsert-page.ps1` is the current content write path. Do not add a second content write path without changing `docs/wordpress-boundaries.md`.

## Publish Gate

Current script warning: `wp-upsert-page.ps1` can publish with `-Publish` or source JSON status `publish`. Those inputs are prohibited until every item in this publish gate has been completed for the named page.

Publishing requires all of the following:

- A clean target URL and slug.
- Fresh `test-wp-auth`, `wp-inventory`, and `check-target` results.
- Browser verification of the draft or staged content.
- An explicit operator request naming the item to publish.
- A rollback note for the affected content.

No script should silently turn a draft into published content. A publish-capable script must make publish intent explicit in the command and output.

## Theme Flow

1. Edit source under `theme/quicksilver-construction/`.
2. Package with `.\scripts\package-theme.ps1`.
3. Review the generated zip path and size.
4. Do not install or activate through this repo until a theme deployment script or runbook exists.

When theme deployment is added, it must include target validation, package validation, WordPress-side verification, and rollback instructions.

## Railway Runtime Flow

Use `.\scripts\railway-status.ps1` for service and volume inventory.

Railway mutations require an explicit task. Before restart, redeploy, volume change, environment variable change, or database exposure:

- Record the target service.
- Check current deploy and logs.
- Name the expected effect.
- Confirm the rollback or recovery step.

## Backup And Export

Before destructive or high-risk operations, create an export or backup appropriate to the surface being changed:

- Content/options/users: WordPress export or database backup.
- Theme source: committed Git state plus packaged zip when deploying.
- Media: WordPress uploads/export path once scripted.
- Railway environment: current variable inventory without secret values.

This repo does not yet contain an active backup/export script, and WP-CLI is not active. Destructive or high-risk DB, option, user, media, plugin, and theme-runtime operations are blocked until a concrete backup/export path exists or an explicit one-time backup runbook is approved.

Full WordPress restore requires both database state and files. Do not treat Git revert as a database rollback. Git can restore repo source; it cannot restore WordPress DB state.

## Release Verification

After a write or runtime operation:

```powershell
.\scripts\check-target.ps1
.\scripts\wp-inventory.ps1
```

Use the in-app browser for visual checks on public pages and authenticated previews. Record only actionable findings in docs or issues; do not keep temporary review notes in the repo.

## Failure Handling

- Stop on authentication failure, unexpected service shape, missing volume, non-WordPress response, database connection error, repeated restart, or ambiguous content target.
- Re-run inventory after fixing the cause.
- Do not continue a release after a failed check without a new explicit operator decision.
