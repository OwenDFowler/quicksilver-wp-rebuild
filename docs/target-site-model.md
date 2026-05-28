# Target Site Model

This document is the human-readable contract for the rebuilt QuickSilver WordPress site. The machine-readable source is `content/site-model.json`.

This phase models the target site only. It does not write to WordPress, deploy a theme, upload media, mutate Railway, publish content, or approve plugins.

## Canonical Pages

| Page | Canonical route | Source evidence | Template role |
| --- | --- | --- | --- |
| Home | `/` | `/` / `home1` | `front-page` |
| Photo Gallery | `/photo-gallery/` | `/project-style-two/` | `page-gallery` |
| Services | `/services/` | `/service/construction-services/` | `page-services` |
| Our Team | `/our-team/` | `/our-team-2/` | `page-standard` |
| Contact | `/contact/` | `/contactus/` | `page-contact` |

Clean target routes are canonical. Source paths are evidence and future redirect candidates only.

Redirect candidates in `content/site-model.json` are inactive planning records, not active redirect configuration.

`sourceRestSlug` means a slug found in the public REST page inventory. `sourceInventorySlug` means the local inventory key used for screenshots and asset evidence. When no public REST page slug exists for a source URL, the model uses `null` rather than a URL path fragment.

## Ownership Contract

Structured JSON owns:

- Business copy.
- Page intent and section order.
- Navigation labels.
- Contact details.
- License text.
- Source evidence.
- Asset intent.

Theme templates own:

- Layout and reusable section rendering.
- Header and footer structure.
- Responsive behavior.
- Typography, colors, buttons, and gallery presentation.
- Visual fidelity to the public source evidence.

WordPress runtime owns:

- Live post IDs, revisions, publish status, and menu assignment.
- Active theme and active plugin state.
- Uploaded media records.
- Contact form runtime once a form implementation is approved.

`content/pages/home.json` is provisional REST draft-write evidence. It is not the target content authority.

## Page Model

### Home

Canonical route: `/`

Sections:

- Hero: QuickSilver welcome, construction imagery, service CTA.
- Quality overview: craftsmanship/reliability copy and service bullets.
- Service cards: Residential Construction, Construction Services, Decks & Outdoors Structures.
- Values band: Mission, Vision, Experience, Commitment.
- Homeowner reasons: planning, communication, skill set, trust.
- Project CTA: Start your next construction project with confidence.
- License banner: `QUICKCL813C1`.

Assets:

- Homepage hero/slider images from `assets/source/inventory/asset-manifest.json`.
- QuickSilver logo/media image.

### Photo Gallery

Canonical route: `/photo-gallery/`

Sections:

- Page title.
- Intro: `Our Work in Action. See What We've Built.`
- Gallery grid/lightbox-style presentation.

Assets:

- `must-recreate` gallery/project images from the source asset manifest.

### Services

Canonical route: `/services/`

Sections:

- Page title: Construction Services.
- Why Choose QuickSilver Construction.
- Service groups: Construction Services, Excavation & Site Preparation, Demolition & Property Improvements.
- Callback pledge for Whidbey homeowners.

### Our Team

Canonical route: `/our-team/`

Sections:

- Page title.
- Team intro: skilled professionals, craftsmanship, reliability, safety, communication, relationships.

No individual team-member names were found in the public source inventory.

### Contact

Canonical route: `/contact/`

Sections:

- Page title.
- Contact methods: email, phone, mailing/location.
- Form placeholder.

The source page shows a contact form surface. The target model does not approve Contact Form 7 or another form plugin. Form implementation remains deferred.

Until a form runtime is approved, the contact form placeholder must collect no user data, submit nowhere, and render only as a non-submitting contact CTA/placeholder.

## No-Build And Reference Content

Do not build these as target pages from the current model:

- `home2`, `home-page-three`: Wastii alternate demo home pages.
- `about-us`, `about-us-2`: not primary nav; reference only.
- `service`, `service2`: alternate service pages; canonical target is `/services/`.
- `project-style-one`: alternate project/gallery demo.
- `contactus-2`: alternate contact page.
- `faq`: not primary nav; client confirmation required before scope.
- `blog`, `blog-grid-view`: blog is not target scope.

Do not build the public source posts. The REST post inventory contains recycling/waste-management demo content and `hello-world`, not QuickSilver rebuild content.

## Asset Policy

The asset manifest remains the source evidence for images:

- `assets/source/inventory/asset-manifest.json`

The local public media copy is documented in:

- `docs/source-media-assets.md`
- `assets/source/media/media-manifest.json`

Motion and interaction behavior is documented in:

- `docs/motion-interaction-inventory.md`
- `assets/source/inventory/motion/motion-capture.json`

Required groups:

- Homepage hero/slider images.
- Photo gallery/project images.
- QuickSilver logo/media reference.

Deferred asset work:

- Map local media files to target sections.
- Finalize alt text during content modeling.

## Plugin Policy

Source-site plugins and theme assets are evidence only:

- Elementor.
- Wastii.
- Slider Revolution.
- Contact Form 7.
- Jetpack.
- Yoast SEO.
- Bluehost/Newfold.

This target model approves no plugins. Any plugin later needs a named owner, feature reason, maintenance risk, and release plan.

## Documentation And Implementation Use

Use this document to understand intent. Use `content/site-model.json` for implementation inputs.

The next phase may generate page JSON, theme section renderers, or an asset acquisition list from the model. It must not treat WordPress live IDs, source slugs, or source plugins as target authority.
