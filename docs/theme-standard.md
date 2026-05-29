# Theme Standard

The target theme is a source-controlled custom WordPress theme at `theme/quicksilver-construction/`. It should create a professional, source-informed QuickSilver site while staying simpler and more controllable than the source site's builder stack. Pixel-exact Wastii/Elementor reproduction is not the goal.

## WordPress Authority

Official WordPress documentation is the authority for theme mechanics:

- [Theme Handbook](https://developer.wordpress.org/themes/)
- [Classic Theme Basics](https://developer.wordpress.org/themes/classic-themes/basics/)
- [Required Theme Files](https://developer.wordpress.org/themes/releasing-your-theme/required-theme-files/)
- [Coding Standards](https://developer.wordpress.org/coding-standards/)
- [Data Validation](https://developer.wordpress.org/apis/security/data-validation/)
- [Escaping Data](https://developer.wordpress.org/apis/security/escaping/)

This repo adds stricter project rules around ownership, release gates, and Codex-first operation.

## Theme Type

The current theme is a classic PHP/CSS theme. Classic theme work must use WordPress theme APIs, template hierarchy, hooks, filters, `functions.php`, enqueued assets, and template parts where they reduce repetition.

Do not introduce Elementor, Slider Revolution, Wastii, or another page-builder dependency for the primary layout unless the project explicitly changes strategy.

## File Rules

- `style.css` must keep the WordPress theme header valid.
- `index.php` must exist as the required base template.
- `front-page.php` may own the homepage presentation when the site uses a static front page.
- `functions.php` owns theme supports, menus, image sizes, enqueues, and theme-level hooks.
- CSS belongs under `assets/css/`; the current primary stylesheet is `assets/css/site.css`.
- JavaScript belongs under `assets/js/` once needed and must be enqueued. Use `assets/js/interactions.js` for shared theme interaction behavior unless the theme structure changes deliberately.
- Source assets belong under `assets/source/`; theme-ready assets belong under the theme only when they are part of the packaged theme.

## Security And Data Handling

- Validate input before action. Required fields, slugs, statuses, file paths, and option values must be checked before writes.
- Use safelists for finite choices such as post status, theme slug, service name, and content type.
- Escape output when echoing at the template boundary with the WordPress function that matches context: `esc_html`, `esc_attr`, `esc_url`, `wp_kses`, or `wp_kses_post`.
- Allow HTML only where the content contract requires it, and document that contract in the source file or content schema.
- Do not echo raw values from post meta, options, REST payloads, query parameters, or source JSON.
- Do not rely on admin-only access as a security boundary.

## CSS And Markup

- Use semantic HTML landmarks and WordPress body classes.
- Use stable, readable class names.
- Keep layout constraints explicit: max widths, grid/flex rules, media queries, image aspect ratios, and overflow behavior.
- Avoid builder-generated class soup and inline style sprawl.
- Preserve accessibility basics: alt text for meaningful images, focus visibility, keyboard-reachable navigation, and sufficient contrast.
- Use the source site's public visual evidence for direction, then prioritize a polished QuickSilver result over exact builder matching. Do not copy brittle implementation details from Wastii, Elementor, or Slider Revolution.

## Plugin Policy

- Plugins are runtime dependencies and must be justified before installation.
- A plugin decision must name the feature it owns, the reason it belongs in a plugin rather than theme/source code, and the maintenance risk.
- Source-site plugin detection is evidence only. It does not approve installation.
- Contact forms, SEO metadata, sliders, galleries, caching, redirects, and analytics each need an owner before plugin work begins.

## Packaging

Package from repo source:

```powershell
.\scripts\check-theme-local.ps1
```

`check-theme-local.ps1` regenerates theme data, checks all theme JavaScript syntax, lints theme PHP through the WordPress image, packages the theme, and runs Git deploy-hygiene checks. The package output is `dist/quicksilver-construction.zip`. `dist/` is generated output and must remain untracked. `package-theme.ps1` is the lower-level zip helper called by the local theme gate.

The repeatable Railway deployment path is the repo-controlled WordPress image:

```powershell
.\scripts\deploy-wordpress-control-image.ps1
.\scripts\verify-railway-wp-cli.ps1
```

Image deployment syncs the theme files into the WordPress volume. It does not activate the theme. Theme activation is a separate explicit DB write:

```powershell
.\scripts\activate-railway-theme.ps1 -ConfirmActivation
```
