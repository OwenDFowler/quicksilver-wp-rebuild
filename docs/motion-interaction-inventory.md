# Motion And Interaction Inventory

This document records the public source-site interaction behavior that matters for the QuickSilver rebuild.

This phase is read-only. It does not write to WordPress, mutate Railway, upload media, deploy a theme, publish content, or approve source-site plugins.

## Evidence

Capture date: 2026-05-28

Primary evidence:

- `assets/source/inventory/motion/motion-capture.json`
- `assets/source/inventory/motion/screenshots/`
- `assets/source/inventory/css-assets.json`
- `assets/source/inventory/js-assets.json`
- `assets/source/inventory/plugin-theme-evidence.json`

Capture command:

```powershell
.\scripts\source-motion-inventory.ps1
```

Captured surfaces:

- Desktop viewport `1440x1200` for Home, Photo Gallery, Services, Our Team, and Contact Us.
- Mobile viewport `390x844` for the homepage header and menu.
- Initial, scrolled, mobile-menu, hero-wait, and gallery-click screenshots where applicable.

The capture loads only public source pages and uses no authentication.

## Source Interaction Stack

The public source pages load these interaction systems:

- Elementor frontend assets.
- Slider Revolution `sr7`.
- Wastii theme JavaScript and CSS.
- FlexSlider.
- Slick.
- Isotope.
- Magnific Popup.
- PrettyPhoto.
- Waypoints.
- Sticky-kit.
- Mousewheel.
- Circle progress.
- Numinate.

These are evidence only. They are not approved target dependencies.

## Rebuild Rule

Recreate the useful visible behavior, not the old dependency stack. Good source-informed interaction design matters more than exact animation matching.

Default implementation path:

- CSS transitions for hover and state changes.
- Vanilla JavaScript for header/menu behavior, hero rotation, lightbox, scroll reveal, and back-to-top behavior.
- `prefers-reduced-motion` support for every animated behavior.
- No Elementor, Wastii, Slider Revolution, jQuery plugin bundle, or commercial slider dependency unless separately approved.

Any later dependency needs a named owner, feature reason, license check, maintenance risk, and release plan.

## Interactions To Recreate

### Header And Navigation

Observed behavior:

- Desktop has a bright green top contact strip.
- Desktop has a separate white main navigation row with logo, centered nav links, and a right-aligned `Get A Quote` link.
- Active nav items use blue text.
- Scrolled desktop screenshots show the white nav row stuck to the top with a drop shadow while page content scrolls underneath.
- Mobile stacks the top contact data vertically in the green strip.
- Mobile shows logo plus an X-style menu control after opening.
- Mobile menu opens as a white panel under the header, with full-width link rows and a blue top border.

Target behavior:

- Recreate the green contact strip and white nav row.
- Use a sticky white nav row after scroll.
- Add a subtle shadow only in the stuck state.
- Use active and hover color transitions on nav links.
- Build the mobile menu with accessible button state, keyboard support, and no page-builder dependency.

Priority: must-recreate.

### Homepage Hero

Observed behavior:

- Home uses a Slider Revolution `sr7-module`.
- Desktop hero is approximately full-width and 750 px tall in the captured viewport.
- Text is centered over darkened construction imagery.
- Visible copy: `Welcome To QuickSilver Construction`, supporting sentence, and `View Our Services!`.
- The 5.2 second capture did not prove a slide change, but source evidence contains multiple hero/slider images.

Target behavior:

- Build a native hero component with the same visual hierarchy.
- Use the local hero image set from the source media manifest.
- If more than one hero image is mapped, use a simple crossfade rotation with no layout shift.
- Pause rotation on hover/focus.
- Disable rotation and long transitions under `prefers-reduced-motion`.

Priority: must-recreate.

### Buttons And Links

Observed behavior:

- The `Get A Quote` header link changes border and text color from dark text to burgundy/red on hover.
- Captured values: dark `rgb(36, 36, 36)` to burgundy `rgb(177, 15, 60)`.
- The source commonly uses border/button transitions rather than large motion for primary CTAs.

Target behavior:

- Recreate color and border transitions for header CTA and similar outline buttons.
- Keep transitions short and restrained.
- Avoid hover-only meaning; active/focus states must also be visible.

Priority: must-recreate.

### Gallery

Observed behavior:

- Photo Gallery uses a three-column desktop image grid.
- Clicking a gallery asset triggered an Elementor lightbox surface.
- The click did not navigate to the image asset directly.
- Source uses lightbox/gallery libraries, but no target library is approved.

Target behavior:

- Build a native gallery grid.
- Add image hover treatment: subtle zoom or overlay with enough contrast to signal clickability.
- Build a small accessible lightbox for gallery images.
- Lightbox must support Escape close, backdrop click close, previous/next controls, focus containment, and visible close button.

Priority: must-recreate.

### Content Cards And Contact Blocks

Observed behavior:

- Contact method cards are large clickable blocks with pale interior card surfaces.
- Hover sampling did not show large transforms; the visual pattern is more about card structure, icon/text grouping, and clickable affordance.
- Service cards and image/text blocks do not need heavy motion to preserve the site feel.

Target behavior:

- Use subtle card hover: border/color emphasis, small shadow, or slight image zoom where appropriate.
- Do not add large lifts, bounces, or decorative animation that the source does not rely on.

Priority: approximate.

### Scroll Effects

Observed behavior:

- Waypoints and animation-oriented assets are loaded.
- The captured pages did not show strong section-by-section reveal requirements.
- Footer animation classes exist in source markup.

Target behavior:

- Use a small IntersectionObserver reveal only if the first theme pass feels too static.
- Default reveal should be subtle: opacity and small translate only.
- Disable under `prefers-reduced-motion`.

Priority: optional.

### Back To Top

Observed behavior:

- Scrolled desktop screenshots show a blue square back-to-top button in the lower-right corner.

Target behavior:

- Recreate a lower-right back-to-top button after scroll.
- Use smooth scroll only when motion is allowed.
- Provide an accessible label.

Priority: must-recreate.

## Interactions To Omit

Do not recreate these as target behaviors from the current evidence:

- Recycling/waste demo post hover surfaces.
- Hidden Wastii demo navigation/blog links detected by generic DOM sampling.
- Circle counters unless real QuickSilver content needs statistics.
- Isotope filtering unless the gallery model later defines categories.
- Sticky-kit sidebars unless a modeled page requires one.
- PrettyPhoto, Magnific Popup, Slick, FlexSlider, or Slider Revolution code paths as dependencies.

## Known Capture Limits

- Generic hover sampling found hidden Wastii/demo links that are not target content.
- Header DOM detection captured broad wrapper nodes; screenshot evidence is stronger for sticky-header behavior.
- The gallery click detected an Elementor lightbox surface, but the screenshot did not capture a visually distinct modal state.
- The hero capture confirmed the Slider Revolution node and visual state, but did not prove slide timing.

These limits do not block the rebuild. They mean the theme should implement the visible interaction categories with simple native behavior, then use browser visual review against the screenshots during the theme phase.

## Theme Implementation Notes

Expected target files:

- `theme/quicksilver-construction/assets/css/site.css`
- `theme/quicksilver-construction/assets/js/interactions.js`

Expected JavaScript modules or functions:

- Header sticky state.
- Mobile menu toggle.
- Hero crossfade.
- Gallery lightbox.
- Back-to-top control.
- Optional scroll reveal.

All interaction code should fail visibly in development if required DOM hooks are missing from a template that declares the behavior. Public pages should not silently claim a behavior that is not wired.
