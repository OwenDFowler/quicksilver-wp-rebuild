[CmdletBinding()]
param(
    [string]$SourceBaseUrl = 'https://zti.sad.mybluehost.me/website_6b4babaf',
    [string]$OutputDir,
    [string]$NodePath = 'C:\Users\owen\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe',
    [string]$NodeModulesDir = 'C:\Users\owen\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\node_modules',
    [string]$PlaywrightModulePath,
    [string]$BrowserExecutablePath,
    [int]$DelayMilliseconds = 1500
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$RepoFullPath = [System.IO.Path]::GetFullPath($RepoRoot)
$SourceMotionRoot = Join-Path $RepoRoot 'assets\source\inventory\motion'
$SourceUserAgent = 'QuickSilverSourceMotionInventory/1.0 (+public-source-site-rebuild)'

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $RepoRoot 'assets\source\inventory\motion'
}

function Assert-UnderRepo {
    param([string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $repoRootWithSeparator = $RepoFullPath.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if ($fullPath -ne $RepoFullPath -and -not $fullPath.StartsWith($repoRootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to write outside repo: $fullPath"
    }
}

function Assert-UnderPath {
    param(
        [string]$Path,
        [string]$ParentPath,
        [string]$Description
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullParent = [System.IO.Path]::GetFullPath($ParentPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if ($fullPath -ne $fullParent.TrimEnd([System.IO.Path]::DirectorySeparatorChar) -and -not $fullPath.StartsWith($fullParent, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "$Description must resolve under $fullParent. Received: $fullPath"
    }
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Value
    )

    Assert-UnderRepo $Path
    $json = $Value | ConvertTo-Json -Depth 30
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $json, $utf8NoBom)
}

function Normalize-SourceBaseUrl {
    param([string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) {
        throw 'SourceBaseUrl is required.'
    }

    $urlWithSlash = $Url.Trim()
    if (-not $urlWithSlash.EndsWith('/')) {
        $urlWithSlash = "$urlWithSlash/"
    }

    $uri = [System.Uri]$urlWithSlash
    if ($uri.Scheme -ne 'https') {
        throw "SourceBaseUrl must use https: $Url"
    }

    return $uri.AbsoluteUri
}

if ($DelayMilliseconds -lt 0) {
    throw 'DelayMilliseconds cannot be negative.'
}

if (-not (Test-Path -LiteralPath $NodePath)) {
    throw "Node executable not found: $NodePath"
}

$playwrightModule = $PlaywrightModulePath
if ([string]::IsNullOrWhiteSpace($playwrightModule)) {
    $pnpmDir = Join-Path $NodeModulesDir '.pnpm'
    if (-not (Test-Path -LiteralPath $pnpmDir)) {
        throw "pnpm node_modules directory not found: $pnpmDir"
    }

    $playwrightCandidates = @(Get-ChildItem -LiteralPath $pnpmDir -Directory -Filter 'playwright@*' | ForEach-Object {
        Join-Path $_.FullName 'node_modules\playwright'
    } | Where-Object {
        Test-Path -LiteralPath $_
    })

    if ($playwrightCandidates.Count -ne 1) {
        throw "Expected exactly one bundled Playwright module, found $($playwrightCandidates.Count)."
    }

    $playwrightModule = $playwrightCandidates[0]
}

if (-not (Test-Path -LiteralPath $playwrightModule)) {
    throw "Playwright module not found: $playwrightModule"
}

if ([string]::IsNullOrWhiteSpace($BrowserExecutablePath)) {
    $browserCandidates = @(
        'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
        'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
        'C:\Program Files\Google\Chrome\Application\chrome.exe',
        'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe'
    )

    $installedBrowsers = @($browserCandidates | Where-Object { Test-Path -LiteralPath $_ })
    if ($installedBrowsers.Count -eq 0) {
        throw 'No local Edge or Chrome executable found for motion inventory capture.'
    }

    $BrowserExecutablePath = $installedBrowsers[0]
}

if (-not (Test-Path -LiteralPath $BrowserExecutablePath)) {
    throw "Browser executable not found: $BrowserExecutablePath"
}

$sourceBase = Normalize-SourceBaseUrl $SourceBaseUrl
$outputFullPath = [System.IO.Path]::GetFullPath($OutputDir)
Assert-UnderPath -Path $outputFullPath -ParentPath $SourceMotionRoot -Description 'Source motion inventory output'
New-Item -ItemType Directory -Force -Path $outputFullPath | Out-Null

$screenshotDir = Join-Path $outputFullPath 'screenshots'
Assert-UnderPath -Path $screenshotDir -ParentPath $SourceMotionRoot -Description 'Source motion screenshot output'
New-Item -ItemType Directory -Force -Path $screenshotDir | Out-Null

$tmpDir = Join-Path $RepoRoot '.tmp\source-motion-inventory'
Assert-UnderRepo $tmpDir
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null

$primaryPages = @(
    [pscustomobject]@{ slug = 'home'; label = 'Home'; path = '' },
    [pscustomobject]@{ slug = 'photo-gallery'; label = 'Photo Gallery'; path = 'project-style-two/' },
    [pscustomobject]@{ slug = 'services'; label = 'Services'; path = 'service/construction-services/' },
    [pscustomobject]@{ slug = 'our-team'; label = 'Our Team'; path = 'our-team-2/' },
    [pscustomobject]@{ slug = 'contact-us'; label = 'Contact Us'; path = 'contactus/' }
)

$jobs = $primaryPages | ForEach-Object {
    [pscustomobject]@{
        slug = $_.slug
        label = $_.label
        url = ([System.Uri]::new([System.Uri]$sourceBase, $_.path)).AbsoluteUri
    }
}

$inputPath = Join-Path $tmpDir 'motion-input.json'
$scriptPath = Join-Path $tmpDir 'motion-capture.cjs'
$outputJsonPath = Join-Path $outputFullPath 'motion-capture.json'

Write-JsonFile -Path $inputPath -Value ([pscustomobject]@{
    sourceBaseUrl = $sourceBase
    outputJsonPath = $outputJsonPath
    screenshotDir = $screenshotDir
    repoRoot = $RepoRoot
    playwrightModule = $playwrightModule
    browserExecutablePath = $BrowserExecutablePath
    userAgent = $SourceUserAgent
    delayMilliseconds = $DelayMilliseconds
    jobs = $jobs
})

$captureScript = @'
const fs = require('fs');
const path = require('path');

const styleProps = [
  'backgroundColor',
  'borderColor',
  'boxShadow',
  'color',
  'opacity',
  'textDecorationLine',
  'transform',
  'transitionDelay',
  'transitionDuration',
  'transitionProperty',
  'transitionTimingFunction'
];

function relative(repoRoot, value) {
  return path.relative(repoRoot, value).replace(/\\/g, '/');
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function unique(values) {
  return [...new Set(values.filter(Boolean))].sort();
}

async function screenshot(page, input, slug, name, fullPage = false) {
  const filePath = path.join(input.screenshotDir, `${slug}-${name}.png`);
  await page.screenshot({ path: filePath, fullPage });
  const stat = fs.statSync(filePath);
  if (stat.size <= 0) {
    throw new Error(`Empty screenshot: ${filePath}`);
  }
  return {
    label: name,
    file: relative(input.repoRoot, filePath),
    bytes: stat.size
  };
}

async function getLibraries(page) {
  return await page.evaluate(() => {
    const resources = performance.getEntriesByType('resource').map((entry) => entry.name);
    const scripts = [...document.scripts].map((node) => node.src).filter(Boolean);
    const stylesheets = [...document.querySelectorAll('link[rel="stylesheet"]')].map((node) => node.href).filter(Boolean);
    const all = [...resources, ...scripts, ...stylesheets];
    const detect = (pattern) => all.some((url) => pattern.test(url)) || pattern.test(document.documentElement.outerHTML);
    return {
      resourceCount: resources.length,
      scriptCount: scripts.length,
      stylesheetCount: stylesheets.length,
      detected: {
        elementor: detect(/elementor/i),
        sliderRevolution: detect(/revslider|sr7|sliderrevolution/i),
        wastiiTheme: detect(/\/themes\/wastii\//i),
        flexslider: detect(/flexslider/i),
        slick: detect(/slick/i),
        isotope: detect(/isotope/i),
        magnificPopup: detect(/magnific/i),
        prettyPhoto: detect(/prettyPhoto|prettyphoto/i),
        waypoints: detect(/waypoints/i),
        stickyKit: detect(/sticky-kit|stick_in_parent/i),
        mousewheel: detect(/mousewheel/i),
        circleProgress: detect(/circle-progress/i),
        numinate: detect(/numinate/i)
      },
      matchedResourceUrls: [...new Set(all.filter((url) => /elementor|revslider|sr7|wastii|flexslider|slick|isotope|magnific|prettyPhoto|prettyphoto|waypoints|sticky-kit|mousewheel|circle-progress|numinate/i.test(url)))].sort()
    };
  });
}

async function getHeaderState(page) {
  return await page.evaluate(() => {
    const candidates = [
      'header',
      '#masthead',
      '.site-header',
      '.tm-header',
      '.themetechmount-header',
      '.tm-header-menu-position',
      '.main-navigation'
    ];
    const visible = (node) => {
      if (!node) return false;
      const rect = node.getBoundingClientRect();
      const style = getComputedStyle(node);
      return rect.width > 0 && rect.height > 0 && style.display !== 'none' && style.visibility !== 'hidden';
    };
    const node = candidates.map((selector) => document.querySelector(selector)).find(visible);
    if (!node) {
      return null;
    }
    const rect = node.getBoundingClientRect();
    const style = getComputedStyle(node);
    return {
      tagName: node.tagName.toLowerCase(),
      id: node.id || '',
      className: node.className || '',
      position: style.position,
      top: style.top,
      backgroundColor: style.backgroundColor,
      boxShadow: style.boxShadow,
      transform: style.transform,
      zIndex: style.zIndex,
      rect: {
        x: Math.round(rect.x),
        y: Math.round(rect.y),
        width: Math.round(rect.width),
        height: Math.round(rect.height)
      }
    };
  });
}

async function getSliderState(page) {
  return await page.evaluate(() => {
    const nodes = [...document.querySelectorAll('rs-module, sr7-module, .rev_slider, .rev_slider_wrapper, .flexslider, .slick-slider')];
    return nodes.slice(0, 5).map((node) => {
      const rect = node.getBoundingClientRect();
      const style = getComputedStyle(node);
      return {
        tagName: node.tagName.toLowerCase(),
        id: node.id || '',
        className: node.className || '',
        text: (node.textContent || '').replace(/\s+/g, ' ').trim().slice(0, 240),
        childCount: node.children.length,
        transform: style.transform,
        opacity: style.opacity,
        rect: {
          x: Math.round(rect.x),
          y: Math.round(rect.y),
          width: Math.round(rect.width),
          height: Math.round(rect.height)
        }
      };
    });
  });
}

async function sampleHover(page, selector, label, limit) {
  const handles = await page.$$(selector);
  const samples = [];
  for (const handle of handles) {
    if (samples.length >= limit) break;
    const before = await handle.evaluate((node, props) => {
      const rect = node.getBoundingClientRect();
      const style = getComputedStyle(node);
      const styleValues = {};
      for (const prop of props) {
        styleValues[prop] = style[prop];
      }
      return {
        text: (node.textContent || node.getAttribute('aria-label') || '').replace(/\s+/g, ' ').trim().slice(0, 120),
        href: node.href || node.getAttribute('href') || '',
        id: node.id || '',
        className: node.className || '',
        viewportHeight: window.innerHeight,
        rect: {
          x: Math.round(rect.x),
          y: Math.round(rect.y),
          width: Math.round(rect.width),
          height: Math.round(rect.height)
        },
        style: styleValues,
        visible: rect.width > 0 && rect.height > 0 && style.display !== 'none' && style.visibility !== 'hidden'
      };
    }, styleProps);
    if (!before.visible || before.rect.y < 0 || before.rect.y + before.rect.height > before.viewportHeight) {
      continue;
    }

    try {
      await handle.hover({ timeout: 5000 });
    } catch (error) {
      const hoverError = String(error.message || error).split('\n')[0];
      samples.push({
        label,
        selector,
        text: before.text,
        href: before.href,
        id: before.id,
        className: before.className,
        rect: before.rect,
        hoverError
      });
      continue;
    }
    await delay(350);

    const after = await handle.evaluate((node, props) => {
      const style = getComputedStyle(node);
      const styleValues = {};
      for (const prop of props) {
        styleValues[prop] = style[prop];
      }
      const overlay = [...node.querySelectorAll('*')].find((child) => {
        const childStyle = getComputedStyle(child);
        const rect = child.getBoundingClientRect();
        return rect.width > 0 && rect.height > 0 && (childStyle.opacity !== '1' || childStyle.transform !== 'none' || childStyle.backgroundColor !== 'rgba(0, 0, 0, 0)');
      });
      return {
        style: styleValues,
        overlayClassName: overlay ? overlay.className || '' : '',
        overlayStyle: overlay ? {
          opacity: getComputedStyle(overlay).opacity,
          transform: getComputedStyle(overlay).transform,
          backgroundColor: getComputedStyle(overlay).backgroundColor
        } : null
      };
    }, styleProps);

    const changedProps = styleProps.filter((prop) => before.style[prop] !== after.style[prop]);
    samples.push({
      label,
      selector,
      text: before.text,
      href: before.href,
      id: before.id,
      className: before.className,
      rect: before.rect,
      changedProps,
      beforeStyle: before.style,
      hoverStyle: after.style,
      hoverOverlay: after.overlayStyle,
      hoverOverlayClassName: after.overlayClassName
    });
  }
  return samples;
}

async function inspectScrollClasses(page) {
  return await page.evaluate(() => {
    const patterns = /animated|animation|elementor-invisible|fade|slide|reveal|waypoint|tm-animation|tm_animated/i;
    return [...document.querySelectorAll('[class]')]
      .filter((node) => patterns.test(node.className))
      .slice(0, 80)
      .map((node) => {
        const rect = node.getBoundingClientRect();
        const style = getComputedStyle(node);
        return {
          tagName: node.tagName.toLowerCase(),
          id: node.id || '',
          className: node.className || '',
          text: (node.textContent || '').replace(/\s+/g, ' ').trim().slice(0, 120),
          opacity: style.opacity,
          transform: style.transform,
          transitionDuration: style.transitionDuration,
          animationName: style.animationName,
          animationDuration: style.animationDuration,
          rect: {
            y: Math.round(rect.y),
            height: Math.round(rect.height)
          }
        };
      });
  });
}

async function inspectGalleryLightbox(page) {
  const result = {
    triggerFound: false,
    triggerHref: '',
    beforeUrl: page.url(),
    afterUrl: '',
    modalDetected: false,
    modalSelectors: [],
    navigatedToAsset: false
  };
  const trigger = page.locator('a[href*="/wp-content/uploads/"], a[href*="i0.wp.com"][href*="/wp-content/uploads/"]').first();
  if (await trigger.count() === 0) {
    return result;
  }

  result.triggerFound = true;
  result.triggerHref = await trigger.getAttribute('href') || '';
  await trigger.scrollIntoViewIfNeeded({ timeout: 5000 });
  await trigger.hover({ timeout: 5000 });
  await delay(350);
  await trigger.click({ timeout: 5000 });
  await delay(1200);
  result.afterUrl = page.url();
  result.modalSelectors = await page.evaluate(() => {
    const selectors = ['.mfp-wrap', '.pp_pic_holder', '.prettyphoto', '.pswp', '.elementor-lightbox', '[role="dialog"]'];
    return selectors.filter((selector) => {
      const node = document.querySelector(selector);
      if (!node) return false;
      const rect = node.getBoundingClientRect();
      const style = getComputedStyle(node);
      return rect.width > 0 && rect.height > 0 && style.display !== 'none' && style.visibility !== 'hidden';
    });
  });
  result.modalDetected = result.modalSelectors.length > 0;
  result.navigatedToAsset = result.afterUrl !== result.beforeUrl && /wp-content\/uploads|i0\.wp\.com/i.test(result.afterUrl);

  await page.keyboard.press('Escape');
  await delay(500);
  if (result.navigatedToAsset) {
    await page.goBack({ waitUntil: 'load', timeout: 30000 });
    await delay(800);
  }
  return result;
}

async function inspectMobileMenu(page) {
  const result = {
    toggleFound: false,
    toggleSelector: '',
    beforeVisibleMenuText: '',
    afterVisibleMenuText: '',
    bodyClassBefore: '',
    bodyClassAfter: '',
    htmlClassBefore: '',
    htmlClassAfter: ''
  };
  const selectors = [
    'button[aria-controls]',
    '.menu-toggle',
    '.navbar-toggle',
    '.tm-mmenu-toggle',
    '.tm-mobile-menu-toggle',
    '.slicknav_btn',
    '.res-991-menu',
    '.header-controls a'
  ];

  for (const selector of selectors) {
    const locators = await page.$$(selector);
    for (const handle of locators) {
      const visible = await handle.evaluate((node) => {
        const rect = node.getBoundingClientRect();
        const style = getComputedStyle(node);
        return rect.width > 0 && rect.height > 0 && style.display !== 'none' && style.visibility !== 'hidden';
      });
      if (!visible) continue;
      result.toggleFound = true;
      result.toggleSelector = selector;
      result.beforeVisibleMenuText = await page.evaluate(() => {
        return [...document.querySelectorAll('nav, .menu, .main-navigation, .site-navigation')]
          .filter((node) => {
            const rect = node.getBoundingClientRect();
            const style = getComputedStyle(node);
            return rect.width > 0 && rect.height > 0 && style.display !== 'none' && style.visibility !== 'hidden';
          })
          .map((node) => (node.textContent || '').replace(/\s+/g, ' ').trim())
          .join(' | ')
          .slice(0, 300);
      });
      result.bodyClassBefore = await page.evaluate(() => document.body.className || '');
      result.htmlClassBefore = await page.evaluate(() => document.documentElement.className || '');
      await handle.click({ timeout: 5000 });
      await delay(800);
      result.bodyClassAfter = await page.evaluate(() => document.body.className || '');
      result.htmlClassAfter = await page.evaluate(() => document.documentElement.className || '');
      result.afterVisibleMenuText = await page.evaluate(() => {
        return [...document.querySelectorAll('nav, .menu, .main-navigation, .site-navigation, .slicknav_nav')]
          .filter((node) => {
            const rect = node.getBoundingClientRect();
            const style = getComputedStyle(node);
            return rect.width > 0 && rect.height > 0 && style.display !== 'none' && style.visibility !== 'hidden';
          })
          .map((node) => (node.textContent || '').replace(/\s+/g, ' ').trim())
          .join(' | ')
          .slice(0, 600);
      });
      return result;
    }
  }
  return result;
}

async function inspectDesktopPage(browser, input, job) {
  const page = await browser.newPage({
    viewport: { width: 1440, height: 1200 },
    userAgent: input.userAgent
  });
  const screenshots = [];
  try {
    await page.goto(job.url, { waitUntil: 'load', timeout: 60000 });
    await delay(input.delayMilliseconds);
    screenshots.push(await screenshot(page, input, job.slug, 'desktop-initial'));
    const libraries = await getLibraries(page);
    const headerInitial = await getHeaderState(page);
    const sliderInitial = await getSliderState(page);
    const scrollClassesInitial = await inspectScrollClasses(page);
    const navHover = await sampleHover(page, 'header a, nav a, .main-navigation a', 'header-nav', 4);
    const buttonHover = await sampleHover(page, 'a.elementor-button, .elementor-button, .tm-btn, a[class*="btn"], button', 'button', 4);
    const cardHover = await sampleHover(page, '.tm-box, .tm-servicebox, .tm-project-box, .elementor-widget-image, .elementor-column, article, .tm-team-member-single', 'card-or-image', 4);

    await page.evaluate(() => window.scrollTo({ top: 900, behavior: 'instant' }));
    await delay(input.delayMilliseconds);
    const headerScrolled = await getHeaderState(page);
    const scrollClassesScrolled = await inspectScrollClasses(page);
    screenshots.push(await screenshot(page, input, job.slug, 'desktop-scrolled'));

    let sliderAfterWait = [];
    if (job.slug === 'home') {
      await page.evaluate(() => window.scrollTo({ top: 0, behavior: 'instant' }));
      await delay(5200);
      sliderAfterWait = await getSliderState(page);
      screenshots.push(await screenshot(page, input, job.slug, 'desktop-hero-after-wait'));
    }

    let galleryLightbox = null;
    if (job.slug === 'photo-gallery') {
      await page.evaluate(() => window.scrollTo({ top: 0, behavior: 'instant' }));
      await delay(500);
      galleryLightbox = await inspectGalleryLightbox(page);
      screenshots.push(await screenshot(page, input, job.slug, 'desktop-gallery-after-click'));
    }

    return {
      slug: job.slug,
      label: job.label,
      url: job.url,
      viewport: 'desktop',
      status: 'ok',
      title: await page.title(),
      libraries,
      header: {
        initial: headerInitial,
        scrolled: headerScrolled
      },
      slider: {
        initial: sliderInitial,
        afterWait: sliderAfterWait
      },
      hoverSamples: [...navHover, ...buttonHover, ...cardHover],
      scrollClassSamples: {
        initial: scrollClassesInitial,
        scrolled: scrollClassesScrolled
      },
      galleryLightbox,
      screenshots
    };
  } finally {
    await page.close();
  }
}

async function inspectMobileHome(browser, input, job) {
  const page = await browser.newPage({
    viewport: { width: 390, height: 844 },
    isMobile: true,
    userAgent: input.userAgent
  });
  const screenshots = [];
  try {
    await page.goto(job.url, { waitUntil: 'load', timeout: 60000 });
    await delay(input.delayMilliseconds);
    screenshots.push(await screenshot(page, input, 'home', 'mobile-initial'));
    const headerInitial = await getHeaderState(page);
    const mobileMenu = await inspectMobileMenu(page);
    screenshots.push(await screenshot(page, input, 'home', 'mobile-menu-after-toggle'));
    await page.evaluate(() => window.scrollTo({ top: 700, behavior: 'instant' }));
    await delay(input.delayMilliseconds);
    const headerScrolled = await getHeaderState(page);
    screenshots.push(await screenshot(page, input, 'home', 'mobile-scrolled'));

    return {
      slug: 'home',
      label: 'Home',
      url: job.url,
      viewport: 'mobile',
      status: 'ok',
      title: await page.title(),
      header: {
        initial: headerInitial,
        scrolled: headerScrolled
      },
      mobileMenu,
      screenshots
    };
  } finally {
    await page.close();
  }
}

(async () => {
  const inputPath = process.argv[2];
  if (!inputPath) {
    throw new Error('Missing motion inventory input path.');
  }
  const input = JSON.parse(fs.readFileSync(inputPath, 'utf8'));
  const { chromium } = require(input.playwrightModule);
  const browser = await chromium.launch({
    headless: true,
    executablePath: input.browserExecutablePath
  });
  const startedAtUtc = new Date().toISOString();
  const pages = [];
  let mobileHome = null;

  try {
    for (const job of input.jobs) {
      pages.push(await inspectDesktopPage(browser, input, job));
      await delay(input.delayMilliseconds);
    }
    mobileHome = await inspectMobileHome(browser, input, input.jobs.find((job) => job.slug === 'home'));
  } finally {
    await browser.close();
  }

  const allScreenshots = [
    ...pages.flatMap((page) => page.screenshots || []),
    ...(mobileHome?.screenshots || [])
  ];
  const result = {
    sourceBaseUrl: input.sourceBaseUrl,
    capturedAtUtc: startedAtUtc,
    delayMilliseconds: input.delayMilliseconds,
    inspectedPages: pages.length,
    pages,
    mobileHome,
    screenshots: allScreenshots
  };
  fs.writeFileSync(input.outputJsonPath, JSON.stringify(result, null, 2));
  console.log(JSON.stringify({
    outputJsonPath: input.outputJsonPath,
    inspectedPages: pages.length,
    screenshotCount: allScreenshots.length
  }, null, 2));
})().catch((error) => {
  console.error(error.stack || error.message || String(error));
  process.exit(1);
});
'@

Set-Content -LiteralPath $scriptPath -Value $captureScript -Encoding utf8

& $NodePath $scriptPath $inputPath
if ($LASTEXITCODE -ne 0) {
    throw "Motion inventory capture failed with exit code $LASTEXITCODE."
}

if (-not (Test-Path -LiteralPath $outputJsonPath)) {
    throw "Motion inventory output missing: $outputJsonPath"
}

$capture = Get-Content -LiteralPath $outputJsonPath -Raw | ConvertFrom-Json
if ($capture.inspectedPages -ne 5) {
    throw "Expected 5 inspected pages, found $($capture.inspectedPages)."
}

$screenshots = @($capture.screenshots)
if ($screenshots.Count -lt 10) {
    throw "Expected at least 10 motion screenshots, found $($screenshots.Count)."
}

[pscustomobject]@{
    Output = $outputJsonPath
    ScreenshotDir = $screenshotDir
    InspectedPages = $capture.inspectedPages
    ScreenshotCount = $screenshots.Count
}
