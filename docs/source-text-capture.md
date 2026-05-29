# Source Text Capture

This document records the public text-preservation snapshot for the QuickSilver source site.

Source URL:

`https://zti.sad.mybluehost.me/website_6b4babaf/`

Capture script:

`scripts/source-public-text-capture.ps1`

Latest capture:

`assets/source/text-capture/20260529T010244Z/`

## What Was Captured

- Raw rendered HTML for every public same-site HTML URL discovered from REST objects and public links.
- Plain-text extraction for each captured HTML page.
- Raw non-HTML public resources discovered through WordPress REST links.
- Full public WordPress REST root JSON.
- Full public WordPress REST type listing.
- Full public REST collection JSON for reachable content collections.
- Per-item plain-text extraction from REST title, excerpt, and content fields.
- SHA-256 checksums and response metadata in `manifest.json`.

Latest capture counts:

- HTML pages: 60.
- HTTP 200 HTML pages: 58.
- Source-linked 404 HTML pages preserved as evidence: 2.
- Non-HTML public resources: 128.
- REST collections attempted: 16.
- REST text items extracted: 153.
- Captured files: 421.
- Captured bytes on disk: 149282340.

## Public WordPress Content Covered

The capture includes full public REST JSON and extracted text for:

- 15 published pages.
- 8 published posts.
- 129 media attachment records.
- 1 navigation record.

The five primary QuickSilver pages were captured as both HTML and text:

- Home: `/website_6b4babaf/`
- Photo Gallery: `/website_6b4babaf/project-style-two/`
- Services: `/website_6b4babaf/service/construction-services/`
- Our Team: `/website_6b4babaf/our-team-2/`
- Contact Us: `/website_6b4babaf/contactus/`

## Limits

This is a public, unauthenticated capture. It does not claim to preserve private WordPress database tables, admin-only settings, unpublished revisions, private Elementor library records, private form submissions, private feedback, or host-account assets.

The manifest records public failures and inaccessible REST collections. In the latest run, Elementor library, feedback, Jetpack forms, menu items, templates, template parts, font family, and global styles endpoints were not publicly readable or did not exist as public collections.

## Important Content Note

The earlier source inventory summarized `Our Team` as having no individual names in the public text inventory. The full REST text capture did preserve the names visible in the page body:

`Pat`, `Darren`, `Nathan`, `Zach`, `Brandon`

Use the full capture as the preservation source. Use `content/site-model.json` as the current target implementation model until it is deliberately updated.
