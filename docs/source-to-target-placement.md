# Source To Target Placement

This table maps preserved public source evidence to the current QuickSilver rebuild model.

Preservation capture:

`assets/source/text-capture/20260529T010244Z/`

Target model:

`content/site-model.json`

## Primary Pages

| Source page | Capture evidence | Target route | Target sections |
| --- | --- | --- | --- |
| `/website_6b4babaf/` | `text/016-website-6b4babaf.txt`, `rest-text/wp-v2-page-home1.txt` | `/` | Hero, quality overview, service cards, values band, homeowner reasons, project CTA, license banner. |
| `/website_6b4babaf/project-style-two/` | `text/005-website-6b4babaf-project-style-two.txt`, `rest-text/wp-v2-page-project-style-two.txt` | `/photo-gallery/` | Page title, gallery intro, gallery grid. |
| `/website_6b4babaf/service/construction-services/` | `text/026-website-6b4babaf-service-construction-services.txt`, public HTML only | `/services/` | Page title, why-choose intro, service groups, callback pledge. |
| `/website_6b4babaf/our-team-2/` | `text/002-website-6b4babaf-our-team-2.txt`, `rest-text/wp-v2-page-our-team-2.txt` | `/our-team/` | Page title, team intro, team-member names. |
| `/website_6b4babaf/contactus/` | `text/010-website-6b4babaf-contactus.txt`, `rest-text/wp-v2-page-contactus.txt` | `/contact/` | Page title, contact methods, non-submitting form placeholder. |

## Shared Chrome

| Source content | Target owner |
| --- | --- |
| Header location, phone, email, navigation, and quote CTA | `content/site-model.json` `siteIdentity` and `navigation`; rendered by theme header. |
| Footer summary, contact details, copyright, license text | `content/site-model.json` `siteIdentity`; rendered by theme footer and homepage license banner. |
| QuickSilver logo/media reference | Theme-ready generated media under `theme/quicksilver-construction/assets/media/generated/`. |

## Media Placement

| Source group | Target owner |
| --- | --- |
| Homepage hero/slider images | `content/site-model.json` homepage hero asset refs; copied into theme generated media by `scripts/generate-theme-data.ps1`. |
| Homepage quality, CTA, and values images | Homepage `mediaSlots`; copied into theme generated media by `scripts/generate-theme-data.ps1`. |
| Photo gallery/project images | Preserved in `assets/source/media/` and represented by the gallery section in `content/site-model.json`; final WordPress upload/media records remain a later runtime step. |
| Team member image resources | Preserved by source media and text capture; not currently placed as runtime team cards unless the target model is deliberately expanded. |

## No-Build Source Content

The Wastii demo pages, recycling blog posts, alternate demos, and private/inaccessible REST collections are preserved as source evidence where publicly reachable. They are not target rebuild content unless `content/site-model.json` is deliberately updated.

## Deployment Boundary

The preservation capture is source evidence for Git. It is not part of the deployed WordPress image. The Railway Docker path copies only `theme/quicksilver-construction/` and `docker/wordpress-start.sh`, and generated theme runtime data is stripped of source-capture paths and source-site URLs.
