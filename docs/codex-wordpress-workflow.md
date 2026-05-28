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

## Bootstrap Flow

Use this only when local credentials or target setup are missing.

1. Create a WordPress application password in wp-admin as a bootstrap action.
2. Run `scripts/init-local-env.ps1` and fill `.env.local` locally.
3. Run `scripts/test-wp-auth.ps1` to prove Codex can authenticate through REST.

## Normal Flow

1. Run `scripts/wp-inventory.ps1` before content writes so Codex sees current WordPress content state.
2. Use `scripts/wp-upsert-page.ps1` to create or update draft pages from `content/pages/*.json` only after the payload is aligned with `content/site-model.json` or explicitly marked provisional.
3. Edit theme/source files locally.
4. Package the theme for review with `scripts/package-theme.ps1`.
5. Deploy the WordPress control image with `scripts/deploy-wordpress-control-image.ps1` when theme/runtime files should sync to Railway.
6. Verify WP-CLI and theme visibility with `scripts/verify-railway-wp-cli.ps1`.
7. Activate the QuickSilver theme only with `scripts/activate-railway-theme.ps1 -ConfirmActivation`.
8. Use REST scripts for content operations and WP-CLI scripts for runtime operations.
9. Verify through the in-app browser and `scripts/check-target.ps1`.

## Durable Rule

If an operation cannot be expressed repeatably from this repo, pause and add a script or doc before doing it a second time.
