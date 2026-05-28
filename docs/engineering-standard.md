# Engineering Standard

This repo is the Codex-first control surface for the QuickSilver WordPress rebuild. The standard here is stricter than ordinary WordPress operation: we prefer a visible failure over code or process that hides uncertainty.

## Authority

- Git owns source-controlled theme code, scripts, docs, content source files, and source asset records.
- WordPress owns live CMS state: database rows, post IDs, revisions, options, uploaded media records, users, active theme state, and active plugin state.
- Railway owns the runtime: services, volumes, environment variables, generated public domain, logs, and deploy status.
- Public source-site inspection is evidence for the rebuild, not an architecture to copy.

For the full ownership contract, use `docs/wordpress-boundaries.md`.

## Required Posture

- Fail fast. Missing env values, missing files, ambiguous slugs, unexpected HTTP responses, and unrecognized runtime state must stop the operation.
- No shims, fallback paths, workaround code, compatibility aliases, or guessed defaults.
- No hidden dual paths. Each operation has one current owner and one current execution path.
- No click-only production process. If an operation matters and recurs, it belongs in a source-controlled script or a documented runbook step.
- No local source drift. Theme files are edited in `theme/quicksilver-construction/`, not through live server file changes.

## Secrets

- Secrets live only in `.env.local`, `.env`, `secrets/`, `exports/private/`, the Railway environment, or the WordPress admin account itself.
- `.env.local` must remain ignored by Git.
- Scripts must not print WordPress application passwords, database passwords, Railway tokens, cookies, or authorization headers.
- If a secret is exposed in terminal output, chat, Git, or docs, revoke it before further work.
- `WORDPRESS_BASE_URL` must use `https://` for this hosted WordPress site. Do not send application passwords over plain HTTP.
- Use one WordPress application password per integration, revoke unused credentials, and rotate credentials after suspected exposure.
- `.env.example` may contain names, service IDs, and non-secret defaults only.

## WordPress Writes

- REST writes default to `draft` unless a publish gate has been explicitly invoked.
- A publish gate requires a fresh inventory, browser verification, a named target URL, and an explicit operator request to publish.
- Current script warning: `scripts/wp-upsert-page.ps1` can publish with `-Publish` or source JSON status `publish`. Those inputs are prohibited until the publish gate has been completed for the named page.
- Content source files in `content/pages/*.json` are the authored source for scripted page writes.
- WordPress post IDs and revision history are runtime facts. Record them only when they help identify the live target; do not treat them as portable source.

## Repeatable Operations

- Use scripts in `scripts/` for authentication checks, inventory, content upserts, target checks, Railway inspection, and theme packaging.
- If a shell command becomes part of normal operation, promote it to a script with validation.
- Scripts must accept explicit input, validate it early, and throw on invalid state.
- Scripts must use structured APIs when available. Current WordPress state should come from REST scripts; WP-CLI may provide state only after it is installed and scripted. Do not parse HTML for WordPress state when a structured path exists.

## Review Gates

Use independent review/fix cycles for architecture-sensitive docs, release procedures, security-affecting scripts, theme deployment paths, plugin decisions, and any change that alters repo-to-WordPress ownership.

At minimum, request two independent reviews:

- Architecture/boundaries: ownership, single-path operation, no doc sprawl, no hidden wp-admin drift.
- WordPress/security/ops: alignment with WordPress docs, application-password handling, validation, escaping, plugin policy, release safety.

Fix every concrete must-fix finding. Repeat the review once when a reviewer still reports a must-fix issue after the first correction pass.

## Documentation Shape

- Write current-state docs, not transition diaries.
- Keep policy in the four standard docs: this file, `docs/wordpress-boundaries.md`, `docs/theme-standard.md`, and `docs/ops-and-release.md`.
- Existing docs should point to these standards instead of restating rules.
- Source-site notes stay factual and public-surface-only.
