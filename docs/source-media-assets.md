# Source Media Assets

This document records the local public media acquisition for the QuickSilver rebuild.

The source evidence remains `assets/source/inventory/asset-manifest.json`. The local media copy is recorded in `assets/source/media/media-manifest.json`.

## Scope

Downloaded assets are limited to source manifest rows with these priorities:

- `must-recreate`
- `candidate`

Reference assets are intentionally excluded. That keeps Wastii, Elementor, and vendor/demo residue out of the local rebuild media set.

## Polite Fetch Rules

Use `scripts/source-media-download.ps1` for this phase.

The script:

- Downloads sequentially.
- Waits 2500 ms between HTTP requests by default.
- Uses only public HTTPS asset URLs from the committed manifest.
- Allows only `zti.sad.mybluehost.me` and `i0.wp.com`.
- Does not authenticate, bypass protections, probe private paths, or follow wp-admin surfaces.
- Fails plainly if a selected asset cannot be fetched as an image.

Run:

```powershell
.\scripts\source-media-download.ps1
```

## Current Local Copy

Latest run:

- Downloaded assets: 29
- Requests made: 29
- Delay between requests: 2500 ms
- Total bytes: 56020805
- Must-recreate assets: 22
- Candidate assets: 7

The public server may return optimized `image/webp` content for source image paths whose URL ends in `.jpg` or `.jpeg`. The local filename extension follows the returned content type. The manifest keeps both the normalized source asset URL and the actual downloaded URL.

## Output

Media files live under:

- `assets/source/media/downloads/must-recreate/`
- `assets/source/media/downloads/candidate/`

The media manifest records:

- Local path.
- Source asset URL.
- Downloaded URL.
- Source page slugs.
- Priority and inferred roles.
- Content type.
- Byte size.
- SHA-256 checksum.
- Source manifest appearances.

These files are source evidence for theme and page modeling. They are not WordPress uploaded media records until a later approved WordPress media upload phase.
