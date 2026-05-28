# Codex WordPress Workflow

## Working Model

Codex should treat this repo as the source of truth for code, docs, content source files, and repeatable operations. WordPress remains the runtime and content database.

The governing rules are:

- `docs/engineering-standard.md`
- `docs/wordpress-boundaries.md`
- `docs/theme-standard.md`
- `docs/ops-and-release.md`

## Control Surfaces

Use the current control-surface roles in `docs/wordpress-boundaries.md`. Do not duplicate those roles here.

## Secret Handling

Create a local `.env.local` from `.env.example` when needed. Keep it untracked.

Expected local secrets:

- `WORDPRESS_USERNAME`
- `WORDPRESS_APPLICATION_PASSWORD`

Do not store database passwords from Railway in this repo. Do not print application passwords, Railway tokens, database credentials, cookies, or authorization headers.

## Near-Term Flow

1. Create a WordPress application password in wp-admin as a bootstrap action.
2. Run `scripts/init-local-env.ps1` and fill `.env.local` locally.
3. Run `scripts/test-wp-auth.ps1` to prove Codex can authenticate through REST.
4. Run `scripts/wp-inventory.ps1` before writes so Codex sees current WordPress state.
5. Use `scripts/wp-upsert-page.ps1` to create or update draft pages from `content/pages/*.json`.
6. Edit theme/source files locally.
7. Package the theme for review; add a deployment script or runbook before installing it.
8. Use REST scripts for current content operations. Add WP-CLI scripts before WP-CLI operations.
9. Verify through the in-app browser and `scripts/check-target.ps1`.

## Durable Rule

If an operation cannot be expressed repeatably from this repo, pause and add a script or doc before doing it a second time.
