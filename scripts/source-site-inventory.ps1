[CmdletBinding()]
param(
    [string]$SourceBaseUrl = 'https://zti.sad.mybluehost.me/website_6b4babaf',
    [string]$OutputDir,
    [string]$NodePath = 'C:\Users\owen\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe',
    [string]$NodeModulesDir = 'C:\Users\owen\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\node_modules',
    [string]$PlaywrightModulePath,
    [string]$BrowserExecutablePath
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$RepoFullPath = [System.IO.Path]::GetFullPath($RepoRoot)
$SourceInventoryRoot = Join-Path $RepoRoot 'assets\source\inventory'
$SourceUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36 QuickSilverSourceInventory/1.0'

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $RepoRoot 'assets\source\inventory'
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

function ConvertTo-SourceUrl {
    param(
        [string]$BaseUrl,
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $decoded = [System.Net.WebUtility]::HtmlDecode($Value.Trim())
    if ($decoded.StartsWith('//')) {
        $decoded = "https:$decoded"
    }

    if ($decoded -match '^(mailto:|tel:|#)') {
        return $decoded
    }

    if ($decoded -match '^(data:|javascript:)') {
        return $null
    }

    return ([System.Uri]::new([System.Uri]$BaseUrl, $decoded)).AbsoluteUri
}

function Get-AttributeValue {
    param(
        [string]$Tag,
        [string]$Name
    )

    $pattern = '(?i)\b' + [regex]::Escape($Name) + '\s*=\s*["'']([^"'']*)["'']'
    $match = [regex]::Match($Tag, $pattern)
    if (-not $match.Success) {
        return $null
    }

    return [System.Net.WebUtility]::HtmlDecode($match.Groups[1].Value)
}

function Convert-HtmlToText {
    param([string]$Html)

    if ([string]::IsNullOrWhiteSpace($Html)) {
        return ''
    }

    $withoutScripts = [regex]::Replace($Html, '<(script|style)\b[^>]*>.*?</\1>', ' ', [System.Text.RegularExpressions.RegexOptions]'IgnoreCase,Singleline')
    $withoutTags = [regex]::Replace($withoutScripts, '<[^>]+>', ' ')
    $decoded = [System.Net.WebUtility]::HtmlDecode($withoutTags)
    return ([regex]::Replace($decoded, '\s+', ' ')).Trim()
}

function Get-PageTitle {
    param([string]$Html)

    $match = [regex]::Match($Html, '<title\b[^>]*>(.*?)</title>', [System.Text.RegularExpressions.RegexOptions]'IgnoreCase,Singleline')
    if (-not $match.Success) {
        return ''
    }

    return Convert-HtmlToText $match.Groups[1].Value
}

function Invoke-SourceRequest {
    param([string]$Url)

    Add-Type -AssemblyName System.Net.Http

    $handler = [System.Net.Http.HttpClientHandler]::new()
    $handler.AllowAutoRedirect = $true
    $client = [System.Net.Http.HttpClient]::new($handler)
    $client.Timeout = [TimeSpan]::FromSeconds(45)
    $client.DefaultRequestHeaders.UserAgent.ParseAdd($SourceUserAgent)

    try {
        $response = $client.GetAsync($Url).GetAwaiter().GetResult()
        $statusCode = [int]$response.StatusCode
        if ($statusCode -ne 200) {
            throw "Unexpected HTTP $statusCode for $Url"
        }

        $bytes = $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
        $content = [System.Text.Encoding]::UTF8.GetString($bytes)
        $headers = @{
            'Content-Type' = if ($null -ne $response.Content.Headers.ContentType) { $response.Content.Headers.ContentType.ToString() } else { '' }
        }

        return [pscustomobject]@{
            StatusCode = $statusCode
            Headers = $headers
            Content = $content
        }
    }
    finally {
        $client.Dispose()
        $handler.Dispose()
    }
}

function Invoke-SourceRest {
    param([string]$Url)

    $response = Invoke-RestMethod -Uri $Url -TimeoutSec 45 -UserAgent $SourceUserAgent
    if ($null -eq $response) {
        throw "Empty REST response from $Url"
    }

    return $response
}

function Get-Links {
    param(
        [string]$BaseUrl,
        [string]$Html
    )

    $matches = [regex]::Matches($Html, '<a\s+[^>]*href=["'']([^"'']+)["''][^>]*>(.*?)</a>', [System.Text.RegularExpressions.RegexOptions]'IgnoreCase,Singleline')
    foreach ($match in $matches) {
        $href = ConvertTo-SourceUrl -BaseUrl $BaseUrl -Value $match.Groups[1].Value
        if ($null -eq $href) {
            continue
        }

        [pscustomobject]@{
            href = $href
            text = Convert-HtmlToText $match.Groups[2].Value
        }
    }
}

function Get-Images {
    param(
        [string]$BaseUrl,
        [string]$Html
    )

    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $matches = [regex]::Matches($Html, '<img\b[^>]*>', [System.Text.RegularExpressions.RegexOptions]'IgnoreCase,Singleline')
    foreach ($match in $matches) {
        $tag = $match.Value
        $srcCandidates = @(
            (Get-AttributeValue -Tag $tag -Name 'src'),
            (Get-AttributeValue -Tag $tag -Name 'data-src'),
            (Get-AttributeValue -Tag $tag -Name 'data-lazy-src')
        ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

        foreach ($src in $srcCandidates) {
            $url = ConvertTo-SourceUrl -BaseUrl $BaseUrl -Value $src
            if ($null -eq $url -or -not $seen.Add($url)) {
                continue
            }

            [pscustomobject]@{
                url = $url
                alt = Get-AttributeValue -Tag $tag -Name 'alt'
                width = Get-AttributeValue -Tag $tag -Name 'width'
                height = Get-AttributeValue -Tag $tag -Name 'height'
            }
        }
    }
}

function Get-AssetUrls {
    param(
        [string]$BaseUrl,
        [string]$Html,
        [string]$TagName,
        [string]$AttributeName
    )

    $pattern = '<' + [regex]::Escape($TagName) + '\b[^>]*\b' + [regex]::Escape($AttributeName) + '=["'']([^"'']+)["''][^>]*>'
    $matches = [regex]::Matches($Html, $pattern, [System.Text.RegularExpressions.RegexOptions]'IgnoreCase,Singleline')
    foreach ($match in $matches) {
        $url = ConvertTo-SourceUrl -BaseUrl $BaseUrl -Value $match.Groups[1].Value
        if ($null -ne $url) {
            $url
        }
    }
}

function Get-Headings {
    param([string]$Html)

    $matches = [regex]::Matches($Html, '<h([1-4])\b[^>]*>(.*?)</h\1>', [System.Text.RegularExpressions.RegexOptions]'IgnoreCase,Singleline')
    foreach ($match in $matches) {
        $text = Convert-HtmlToText $match.Groups[2].Value
        if ([string]::IsNullOrWhiteSpace($text)) {
            continue
        }

        [pscustomobject]@{
            level = [int]$match.Groups[1].Value
            text = $text
        }
    }
}

function Get-PluginThemeEvidence {
    param([object[]]$AssetUrls)

    $items = @()
    foreach ($url in $AssetUrls) {
        $pluginMatch = [regex]::Match($url, '/wp-content/plugins/([^/]+)/', [System.Text.RegularExpressions.RegexOptions]'IgnoreCase')
        if ($pluginMatch.Success) {
            $items += [pscustomobject]@{
                type = 'plugin'
                slug = $pluginMatch.Groups[1].Value
                evidence = 'asset-url'
                url = $url
                route = $null
            }
            continue
        }

        $themeMatch = [regex]::Match($url, '/wp-content/themes/([^/]+)/', [System.Text.RegularExpressions.RegexOptions]'IgnoreCase')
        if ($themeMatch.Success) {
            $items += [pscustomobject]@{
                type = 'theme'
                slug = $themeMatch.Groups[1].Value
                evidence = 'asset-url'
                url = $url
                route = $null
            }
        }
    }

    $items | Sort-Object type, slug, url -Unique
}

function Get-ImageRole {
    param(
        [string]$PageSlug,
        [string]$Url,
        [string]$Alt
    )

    $value = "$Url $Alt"
    if ($value -match '(?i)(blog-|wastii|themetechmount|logo-dark\.svg)') {
        return 'theme/demo reference'
    }
    if ($value -match '(?i)logo') {
        return 'logo/media reference'
    }
    if ($PageSlug -eq 'home' -and $value -match '(?i)(10-2|18-scaled|30-scaled)') {
        return 'homepage hero/slider'
    }
    if ($PageSlug -eq 'photo-gallery') {
        return 'gallery/project image'
    }
    if ($value -match '(?i)(blog-|wastii|themetechmount)') {
        return 'theme/demo reference'
    }

    return 'content image'
}

function Get-ImagePriority {
    param(
        [string]$Role,
        [string]$Url
    )

    if ($Role -eq 'theme/demo reference' -or $Url -match '(?i)/2022/|themetechmount') {
        return 'reference'
    }
    if ($Role -match 'homepage hero|logo|gallery') {
        return 'must-recreate'
    }

    return 'candidate'
}

$sourceBase = Normalize-SourceBaseUrl $SourceBaseUrl
$outputFullPath = [System.IO.Path]::GetFullPath($OutputDir)
Assert-UnderPath -Path $outputFullPath -ParentPath $SourceInventoryRoot -Description 'Source inventory output'
New-Item -ItemType Directory -Force -Path $outputFullPath | Out-Null

$screenshotDir = Join-Path $outputFullPath 'screenshots'
Assert-UnderPath -Path $screenshotDir -ParentPath $SourceInventoryRoot -Description 'Source inventory screenshot output'
New-Item -ItemType Directory -Force -Path $screenshotDir | Out-Null

$primaryPages = @(
    [pscustomobject]@{ slug = 'home'; label = 'Home'; path = '' },
    [pscustomobject]@{ slug = 'photo-gallery'; label = 'Photo Gallery'; path = 'project-style-two/' },
    [pscustomobject]@{ slug = 'services'; label = 'Services'; path = 'service/construction-services/' },
    [pscustomobject]@{ slug = 'our-team'; label = 'Our Team'; path = 'our-team-2/' },
    [pscustomobject]@{ slug = 'contact-us'; label = 'Contact Us'; path = 'contactus/' }
)

$crawlStartedAt = (Get-Date).ToUniversalTime().ToString('o')
$restRootUrl = "$sourceBase`wp-json/"
$restPagesUrl = "$sourceBase`wp-json/wp/v2/pages?per_page=100&_fields=id,slug,link,title,status,menu_order,parent"
$restPostsUrl = "$sourceBase`wp-json/wp/v2/posts?per_page=100&_fields=id,slug,link,title,status,date"

$restRoot = Invoke-SourceRest $restRootUrl
$restPages = @(Invoke-SourceRest $restPagesUrl)
$restPosts = @(Invoke-SourceRest $restPostsUrl)

if ($null -eq $restRoot.routes -or @($restPages).Count -eq 0) {
    throw 'Malformed source REST response: expected routes and at least one page.'
}

$allPageInventories = @()
$allLinks = @()
$allImages = @()
$allCss = @()
$allJs = @()

foreach ($primary in $primaryPages) {
    $url = ([System.Uri]::new([System.Uri]$sourceBase, $primary.path)).AbsoluteUri
    $response = Invoke-SourceRequest $url
    $html = $response.Content
    $links = @(Get-Links -BaseUrl $url -Html $html)
    $images = @(Get-Images -BaseUrl $url -Html $html)
    $css = @(Get-AssetUrls -BaseUrl $url -Html $html -TagName 'link' -AttributeName 'href' | Where-Object { $_ -match '\.css|/wp-content/' } | Sort-Object -Unique)
    $js = @(Get-AssetUrls -BaseUrl $url -Html $html -TagName 'script' -AttributeName 'src' | Sort-Object -Unique)
    $headings = @(Get-Headings $html)

    $allLinks += $links | ForEach-Object {
        [pscustomobject]@{
            sourcePageSlug = $primary.slug
            sourcePageUrl = $url
            href = $_.href
            text = $_.text
        }
    }

    $allImages += $images | ForEach-Object {
        [pscustomobject]@{
            sourcePageSlug = $primary.slug
            sourcePageUrl = $url
            url = $_.url
            alt = $_.alt
            width = $_.width
            height = $_.height
        }
    }

    $allCss += $css | ForEach-Object {
        [pscustomobject]@{
            sourcePageSlug = $primary.slug
            sourcePageUrl = $url
            url = $_
        }
    }

    $allJs += $js | ForEach-Object {
        [pscustomobject]@{
            sourcePageSlug = $primary.slug
            sourcePageUrl = $url
            url = $_
        }
    }

    $allPageInventories += [pscustomobject]@{
        slug = $primary.slug
        label = $primary.label
        url = $url
        statusCode = $response.StatusCode
        contentType = $response.Headers['Content-Type']
        title = Get-PageTitle $html
        htmlLength = $html.Length
        headings = $headings
        linkCount = $links.Count
        imageCount = $images.Count
        cssCount = $css.Count
        jsCount = $js.Count
    }
}

$pageMap = $restPages | ForEach-Object {
    [pscustomobject]@{
        id = $_.id
        slug = $_.slug
        status = $_.status
        menuOrder = $_.menu_order
        parent = $_.parent
        title = $_.title.rendered
        link = $_.link
        buildScope = if ($_.slug -in @('home1', 'project-style-two', 'contactus', 'our-team-2')) { 'primary-or-primary-reference' } elseif ($_.slug -match 'home2|home-page-three|blog|faq|about-us|service2|project-style-one') { 'reference-or-demo' } else { 'review' }
    }
}

$postMap = $restPosts | ForEach-Object {
    [pscustomobject]@{
        id = $_.id
        slug = $_.slug
        status = $_.status
        date = $_.date
        title = $_.title.rendered
        link = $_.link
        buildScope = if ($_.slug -match 'waste|plastic|recycl|hello-world|upcycling|dumpster|baler|compactor') { 'demo-no-build' } else { 'review' }
    }
}

$allAssetUrls = @($allCss.url + $allJs.url) | Sort-Object -Unique
$pluginThemeEvidence = @(Get-PluginThemeEvidence $allAssetUrls)
$routeEvidenceRules = @(
    [pscustomobject]@{ pattern = '^/contact-form-7/'; type = 'plugin'; slug = 'contact-form-7' },
    [pscustomobject]@{ pattern = '^/elementor'; type = 'plugin'; slug = 'elementor' },
    [pscustomobject]@{ pattern = '^/jetpack/'; type = 'plugin'; slug = 'jetpack' },
    [pscustomobject]@{ pattern = '^/newfold-ai/'; type = 'plugin'; slug = 'newfold-ai' },
    [pscustomobject]@{ pattern = '^/yoast/'; type = 'plugin'; slug = 'yoast-seo' }
)

$routeEvidence = @()
foreach ($routeName in ($restRoot.routes.PSObject.Properties.Name | Sort-Object)) {
    foreach ($rule in $routeEvidenceRules) {
        if ($routeName -match $rule.pattern) {
            $routeEvidence += [pscustomobject]@{
                type = $rule.type
                slug = $rule.slug
                evidence = 'rest-route'
                url = $restRootUrl
                route = $routeName
            }
        }
    }
}

$pluginThemeEvidence = @($pluginThemeEvidence + $routeEvidence) | Sort-Object type, slug, evidence, url, route -Unique

$assetManifest = $allImages | Sort-Object sourcePageSlug, url -Unique | ForEach-Object {
    $role = Get-ImageRole -PageSlug $_.sourcePageSlug -Url $_.url -Alt $_.alt
    [pscustomobject]@{
        sourcePageSlug = $_.sourcePageSlug
        sourcePageUrl = $_.sourcePageUrl
        url = $_.url
        alt = $_.alt
        inferredRole = $role
        priority = Get-ImagePriority -Role $role -Url $_.url
        evidence = 'public img tag'
    }
}

$crawlSummary = [pscustomobject]@{
    sourceBaseUrl = $sourceBase
    crawledAtUtc = $crawlStartedAt
    interfaces = @(
        $sourceBase,
        $restRootUrl,
        $restPagesUrl,
        $restPostsUrl
    )
    primaryPages = $allPageInventories
    restPageCount = @($restPages).Count
    restPostCount = @($restPosts).Count
    pluginThemeEvidenceCount = @($pluginThemeEvidence).Count
    imageAssetCount = @($assetManifest).Count
}

Write-JsonFile -Path (Join-Path $outputFullPath 'crawl-summary.json') -Value $crawlSummary
Write-JsonFile -Path (Join-Path $outputFullPath 'primary-pages.json') -Value $allPageInventories
Write-JsonFile -Path (Join-Path $outputFullPath 'rest-pages.json') -Value $pageMap
Write-JsonFile -Path (Join-Path $outputFullPath 'rest-posts.json') -Value $postMap
Write-JsonFile -Path (Join-Path $outputFullPath 'links.json') -Value ($allLinks | Sort-Object sourcePageSlug, href, text -Unique)
Write-JsonFile -Path (Join-Path $outputFullPath 'asset-manifest.json') -Value $assetManifest
Write-JsonFile -Path (Join-Path $outputFullPath 'css-assets.json') -Value ($allCss | Sort-Object sourcePageSlug, url -Unique)
Write-JsonFile -Path (Join-Path $outputFullPath 'js-assets.json') -Value ($allJs | Sort-Object sourcePageSlug, url -Unique)
Write-JsonFile -Path (Join-Path $outputFullPath 'plugin-theme-evidence.json') -Value $pluginThemeEvidence

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
        throw 'No local Edge or Chrome executable found for screenshot capture.'
    }

    $BrowserExecutablePath = $installedBrowsers[0]
}

if (-not (Test-Path -LiteralPath $BrowserExecutablePath)) {
    throw "Browser executable not found: $BrowserExecutablePath"
}

$tmpDir = Join-Path $RepoRoot '.tmp\source-site-inventory'
Assert-UnderRepo $tmpDir
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null

$screenshotInputPath = Join-Path $tmpDir 'screenshots-input.json'
$screenshotScriptPath = Join-Path $tmpDir 'screenshots.cjs'

$screenshotJobs = @()
foreach ($primary in $primaryPages) {
    $url = ([System.Uri]::new([System.Uri]$sourceBase, $primary.path)).AbsoluteUri
    $screenshotJobs += [pscustomobject]@{
        slug = $primary.slug
        label = $primary.label
        url = $url
        viewportName = 'desktop'
        width = 1440
        height = 1200
        path = Join-Path $screenshotDir "$($primary.slug)-desktop.png"
    }
    $screenshotJobs += [pscustomobject]@{
        slug = $primary.slug
        label = $primary.label
        url = $url
        viewportName = 'mobile'
        width = 390
        height = 844
        path = Join-Path $screenshotDir "$($primary.slug)-mobile.png"
    }
}

Write-JsonFile -Path $screenshotInputPath -Value ([pscustomobject]@{
    playwrightModule = $playwrightModule
    browserExecutablePath = $BrowserExecutablePath
    jobs = $screenshotJobs
})

$screenshotScript = @'
const fs = require('fs');

(async () => {
  const inputPath = process.argv[2];
  if (!inputPath) {
    throw new Error('Missing screenshot input path.');
  }

  const input = JSON.parse(fs.readFileSync(inputPath, 'utf8'));
  const { chromium } = require(input.playwrightModule);
  const browser = await chromium.launch({
    headless: true,
    executablePath: input.browserExecutablePath
  });

  try {
    for (const job of input.jobs) {
      const page = await browser.newPage({
        viewport: { width: job.width, height: job.height },
        deviceScaleFactor: 1,
        isMobile: job.viewportName === 'mobile'
      });
      await page.goto(job.url, { waitUntil: 'load', timeout: 60000 });
      await page.waitForTimeout(1500);
      await page.screenshot({ path: job.path, fullPage: true });
      await page.close();

      const stat = fs.statSync(job.path);
      if (stat.size <= 0) {
        throw new Error(`Screenshot is empty: ${job.path}`);
      }
      console.log(`${job.slug}:${job.viewportName}:${stat.size}`);
    }
  } finally {
    await browser.close();
  }
})().catch((error) => {
  console.error(error.stack || error.message || String(error));
  process.exit(1);
});
'@

Set-Content -LiteralPath $screenshotScriptPath -Value $screenshotScript -Encoding utf8

& $NodePath $screenshotScriptPath $screenshotInputPath
if ($LASTEXITCODE -ne 0) {
    throw "Screenshot capture failed with exit code $LASTEXITCODE."
}

$screenshotFiles = Get-ChildItem -LiteralPath $screenshotDir -Filter '*.png' | Sort-Object Name | ForEach-Object {
    [pscustomobject]@{
        file = $_.FullName.Substring($RepoRoot.Length + 1)
        bytes = $_.Length
    }
}

Write-JsonFile -Path (Join-Path $outputFullPath 'screenshots.json') -Value $screenshotFiles

[pscustomobject]@{
    SourceBaseUrl = $sourceBase
    OutputDir = $outputFullPath
    PrimaryPageCount = @($allPageInventories).Count
    RestPageCount = @($restPages).Count
    RestPostCount = @($restPosts).Count
    AssetCount = @($assetManifest).Count
    ScreenshotCount = @($screenshotFiles).Count
}
