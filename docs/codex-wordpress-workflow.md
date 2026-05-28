# Codex WordPress Workflow

## Working Model

Codex should treat this repo as the source of truth for code and repeatable operations. WordPress remains the runtime and content database.

Use wp-admin only for bootstrap or emergency manual edits. Day-to-day work should happen through this repo, Railway CLI, WordPress REST, and a clean WP-CLI path once installed.

## Control Surfaces

- Railway CLI: service status, logs, restarts, deploy inspection, SSH.
- WordPress REST: pages, posts, media, menus, settings that are exposed through REST.
- WP-CLI: future terminal-first admin path for themes, plugins, users, options, exports, and imports.
- In-app browser: visual verification of public pages after changes.

## Secret Handling

Create a local `.env` or `.env.local` from `.env.example` when needed. Keep it untracked.

Expected future local secrets:

- `WORDPRESS_USERNAME`
- `WORDPRESS_APPLICATION_PASSWORD`

Do not store database passwords from Railway in this repo.

## Near-Term Flow

1. Create a WordPress application password in wp-admin.
2. Run `scripts/init-local-env.ps1` and fill `.env.local` locally.
3. Run `scripts/test-wp-auth.ps1` to prove Codex can authenticate through REST.
4. Edit theme/source files locally.
5. Package or sync the theme.
6. Use REST/WP-CLI scripts for content and settings.
7. Verify through the in-app browser and `scripts/check-target.ps1`.

## Durable Rule

If an operation cannot be expressed repeatably from this repo, pause and add a script or doc before doing it a second time.
