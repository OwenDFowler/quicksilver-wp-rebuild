[CmdletBinding()]
param(
    [string]$SourceBaseUrl = 'https://zti.sad.mybluehost.me/website_6b4babaf',
    [string]$OutputRoot,
    [int]$MaxHtmlPages = 200,
    [int]$TimeoutSeconds = 45
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$RepoFullPath = [System.IO.Path]::GetFullPath($RepoRoot)
$TextCaptureRoot = Join-Path $RepoRoot 'assets\source\text-capture'
$SourceUserAgent = 'QuickSilverPublicTextCapture/1.0 (+public-source-preservation)'

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $RepoRoot 'assets\source\text-capture'
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

function Write-Utf8File {
    param(
        [string]$Path,
        [string]$Value
    )

    Assert-UnderRepo $Path
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $Value, $utf8NoBom)
}

function Write-BytesFile {
    param(
        [string]$Path,
        [byte[]]$Value
    )

    Assert-UnderRepo $Path
    [System.IO.File]::WriteAllBytes($Path, $Value)
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Value,
        [int]$Depth = 60
    )

    $json = $Value | ConvertTo-Json -Depth $Depth
    Write-Utf8File -Path $Path -Value $json
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

function ConvertTo-CaptureUrl {
    param(
        [string]$BaseUrl,
        [string]$Candidate
    )

    if ([string]::IsNullOrWhiteSpace($Candidate)) {
        return $null
    }

    $value = [System.Net.WebUtility]::HtmlDecode($Candidate.Trim())
    if ($value.StartsWith('//')) {
        $value = "https:$value"
    }
    if ($value -match '^(mailto:|tel:|javascript:|data:|#)') {
        return $null
    }

    $uri = [System.Uri]::new([System.Uri]$BaseUrl, $value)
    $builder = [System.UriBuilder]::new($uri)
    $builder.Fragment = ''
    $builder.Query = ''
    return $builder.Uri.AbsoluteUri
}

function ConvertTo-SafeName {
    param(
        [string]$Url,
        [int]$Index
    )

    $uri = [System.Uri]$Url
    $path = $uri.AbsolutePath.Trim('/')
    if ([string]::IsNullOrWhiteSpace($path)) {
        $path = 'home'
    }

    $safe = $path.ToLowerInvariant()
    $safe = [regex]::Replace($safe, '[^a-z0-9]+', '-')
    $safe = $safe.Trim('-')
    if ([string]::IsNullOrWhiteSpace($safe)) {
        $safe = 'page'
    }
    if ($safe.Length -gt 100) {
        $safe = $safe.Substring(0, 100).Trim('-')
    }

    return ('{0:d3}-{1}' -f $Index, $safe)
}

function Get-ExtensionForContentType {
    param(
        [string]$ContentType,
        [string]$Fallback = '.bin'
    )

    $normalized = ''
    if (-not [string]::IsNullOrWhiteSpace($ContentType)) {
        $normalized = $ContentType.Split(';')[0].Trim().ToLowerInvariant()
    }

    switch ($normalized) {
        'text/html' { return '.html' }
        'text/plain' { return '.txt' }
        'application/json' { return '.json' }
        'image/jpeg' { return '.jpg' }
        'image/png' { return '.png' }
        'image/webp' { return '.webp' }
        'image/gif' { return '.gif' }
        'image/svg+xml' { return '.svg' }
        default { return $Fallback }
    }
}

function Get-Sha256Hex {
    param([byte[]]$Bytes)

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString($sha256.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha256.Dispose()
    }
}

function Convert-HtmlToText {
    param([string]$Html)

    if ([string]::IsNullOrWhiteSpace($Html)) {
        return ''
    }

    $withoutScripts = [regex]::Replace($Html, '<(script|style|noscript)\b[^>]*>.*?</\1>', ' ', [System.Text.RegularExpressions.RegexOptions]'IgnoreCase,Singleline')
    $withoutTags = [regex]::Replace($withoutScripts, '<[^>]+>', ' ')
    $decoded = [System.Net.WebUtility]::HtmlDecode($withoutTags)
    return ([regex]::Replace($decoded, '[\t\r\n ]+', ' ')).Trim()
}

function Get-Hrefs {
    param(
        [string]$PageUrl,
        [string]$Html
    )

    $matches = [regex]::Matches($Html, '<a\s+[^>]*href=["'']([^"'']+)["'']', [System.Text.RegularExpressions.RegexOptions]'IgnoreCase,Singleline')
    foreach ($match in $matches) {
        ConvertTo-CaptureUrl -BaseUrl $PageUrl -Candidate $match.Groups[1].Value
    }
}

function Invoke-TextCaptureRequest {
    param([string]$Url)

    $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $Url)
    $request.Headers.UserAgent.ParseAdd($SourceUserAgent)

    $response = $script:HttpClient.SendAsync($request).GetAwaiter().GetResult()
    try {
        $bytes = $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
        $contentType = ''
        if ($null -ne $response.Content.Headers.ContentType) {
            $contentType = $response.Content.Headers.ContentType.ToString()
        }

        return [pscustomobject]@{
            Url = $Url
            StatusCode = [int]$response.StatusCode
            ContentType = $contentType
            Bytes = $bytes
            Text = [System.Text.Encoding]::UTF8.GetString($bytes)
            HeaderTotalPages = if ($response.Headers.Contains('X-WP-TotalPages')) { @($response.Headers.GetValues('X-WP-TotalPages'))[0] } else { $null }
        }
    }
    finally {
        $response.Dispose()
        $request.Dispose()
    }
}

function Get-RestCollection {
    param(
        [string]$EndpointUrl,
        [string]$Name,
        [string]$OutputDir
    )

    $items = @()
    $responses = @()
    $page = 1
    $totalPages = 1

    do {
        $separator = if ($EndpointUrl.Contains('?')) { '&' } else { '?' }
        $pageUrl = "$EndpointUrl${separator}per_page=100&page=$page&context=view"
        $response = Invoke-TextCaptureRequest $pageUrl
        $relativeFile = Join-Path 'rest' "$Name-page-$page.json"
        Write-Utf8File -Path (Join-Path $OutputDir $relativeFile) -Value $response.Text

        $responses += [pscustomobject]@{
            url = $pageUrl
            statusCode = $response.StatusCode
            contentType = $response.ContentType
            bytes = $response.Bytes.Length
            sha256 = Get-Sha256Hex $response.Bytes
            file = $relativeFile.Replace('\', '/')
        }

        if ($response.StatusCode -lt 200 -or $response.StatusCode -gt 299) {
            break
        }

        $parsed = $response.Text | ConvertFrom-Json
        $items += @($parsed)

        if ($null -ne $response.HeaderTotalPages) {
            $totalPages = [int]$response.HeaderTotalPages
        }

        $page += 1
    } while ($page -le $totalPages)

    return [pscustomobject]@{
        name = $Name
        endpointUrl = $EndpointUrl
        itemCount = @($items).Count
        responses = $responses
        items = $items
    }
}

Assert-UnderPath -Path $OutputRoot -ParentPath $TextCaptureRoot -Description 'Source text-capture output'
if ($MaxHtmlPages -lt 1) {
    throw 'MaxHtmlPages must be at least 1.'
}
if ($TimeoutSeconds -lt 1) {
    throw 'TimeoutSeconds must be at least 1.'
}

$sourceBase = Normalize-SourceBaseUrl $SourceBaseUrl
$sourceBaseUri = [System.Uri]$sourceBase
$timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$captureDir = Join-Path $OutputRoot $timestamp
Assert-UnderPath -Path $captureDir -ParentPath $TextCaptureRoot -Description 'Source text-capture run output'
New-Item -ItemType Directory -Force -Path (Join-Path $captureDir 'html') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $captureDir 'text') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $captureDir 'resources') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $captureDir 'rest') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $captureDir 'rest-text') | Out-Null

Add-Type -AssemblyName System.Net.Http
$handler = [System.Net.Http.HttpClientHandler]::new()
$handler.AllowAutoRedirect = $true
$script:HttpClient = [System.Net.Http.HttpClient]::new($handler)
$script:HttpClient.Timeout = [TimeSpan]::FromSeconds($TimeoutSeconds)

$requiredHtmlSeeds = @(
    $sourceBase,
    ([System.Uri]::new($sourceBaseUri, 'project-style-two/')).AbsoluteUri,
    ([System.Uri]::new($sourceBaseUri, 'service/construction-services/')).AbsoluteUri,
    ([System.Uri]::new($sourceBaseUri, 'our-team-2/')).AbsoluteUri,
    ([System.Uri]::new($sourceBaseUri, 'contactus/')).AbsoluteUri
)

$htmlQueue = [System.Collections.Generic.Queue[string]]::new()
$queued = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$capturedHtml = @()
$capturedResources = @()
$restCollections = @()
$restTypes = $null
$restSearch = $null

try {
    $restRootUrl = ([System.Uri]::new($sourceBaseUri, 'wp-json/')).AbsoluteUri
    $restRootResponse = Invoke-TextCaptureRequest $restRootUrl
    Write-Utf8File -Path (Join-Path $captureDir 'rest\wp-json-root.json') -Value $restRootResponse.Text
    if ($restRootResponse.StatusCode -ne 200) {
        throw "Expected HTTP 200 for REST root, got $($restRootResponse.StatusCode): $restRootUrl"
    }

    $typesUrl = ([System.Uri]::new($sourceBaseUri, 'wp-json/wp/v2/types')).AbsoluteUri
    $typesResponse = Invoke-TextCaptureRequest $typesUrl
    Write-Utf8File -Path (Join-Path $captureDir 'rest\wp-v2-types.json') -Value $typesResponse.Text
    if ($typesResponse.StatusCode -ne 200) {
        throw "Expected HTTP 200 for REST types, got $($typesResponse.StatusCode): $typesUrl"
    }
    $restTypes = $typesResponse.Text | ConvertFrom-Json

    $restSearchUrl = ([System.Uri]::new($sourceBaseUri, 'wp-json/wp/v2/search?subtype=any')).AbsoluteUri
    $restSearch = Get-RestCollection -EndpointUrl $restSearchUrl -Name 'wp-v2-search-any' -OutputDir $captureDir

    foreach ($typeProperty in ($restTypes.PSObject.Properties | Sort-Object Name)) {
        $restBase = [string]$typeProperty.Value.rest_base
        if ([string]::IsNullOrWhiteSpace($restBase) -or $restBase -match '[()]') {
            continue
        }

        $name = "wp-v2-$($typeProperty.Name)"
        $endpointUrl = ([System.Uri]::new($sourceBaseUri, "wp-json/wp/v2/$restBase")).AbsoluteUri
        $collection = Get-RestCollection -EndpointUrl $endpointUrl -Name $name -OutputDir $captureDir
        $restCollections += $collection

        foreach ($item in @($collection.items)) {
            if ($null -ne $item.link) {
                $candidate = ConvertTo-CaptureUrl -BaseUrl $sourceBase -Candidate $item.link
                if ($null -ne $candidate -and $queued.Add($candidate)) {
                    $htmlQueue.Enqueue($candidate)
                }
            }
        }
    }

    foreach ($seed in $requiredHtmlSeeds) {
        $candidate = ConvertTo-CaptureUrl -BaseUrl $sourceBase -Candidate $seed
        if ($null -ne $candidate -and $queued.Add($candidate)) {
            $htmlQueue.Enqueue($candidate)
        }
    }

    $htmlIndex = 0
    while ($htmlQueue.Count -gt 0) {
        if ($htmlIndex -ge $MaxHtmlPages) {
            throw "HTML capture exceeded MaxHtmlPages=$MaxHtmlPages."
        }

        $url = $htmlQueue.Dequeue()
        $uri = [System.Uri]$url
        if ($uri.Host -ne $sourceBaseUri.Host -or -not $uri.AbsolutePath.StartsWith($sourceBaseUri.AbsolutePath, [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }
        if ($uri.AbsolutePath -match '\.(css|js|jpe?g|png|gif|webp|svg|ico|pdf|zip|woff2?|ttf|eot)$') {
            continue
        }
        if ($uri.AbsolutePath -match '/(wp-content|wp-includes|wp-admin|wp-json)/') {
            continue
        }

        $response = Invoke-TextCaptureRequest $url
        if ($response.ContentType -match 'text/html') {
            $htmlIndex += 1
            $safeName = ConvertTo-SafeName -Url $url -Index $htmlIndex
            $htmlRelative = "html/$safeName.html"
            $textRelative = "text/$safeName.txt"
            Write-Utf8File -Path (Join-Path $captureDir $htmlRelative) -Value $response.Text

            $extractedText = Convert-HtmlToText $response.Text
            Write-Utf8File -Path (Join-Path $captureDir $textRelative) -Value $extractedText

            foreach ($href in (Get-Hrefs -PageUrl $url -Html $response.Text)) {
                if ($null -eq $href) {
                    continue
                }
                $hrefUri = [System.Uri]$href
                if ($hrefUri.Host -eq $sourceBaseUri.Host -and $hrefUri.AbsolutePath.StartsWith($sourceBaseUri.AbsolutePath, [System.StringComparison]::OrdinalIgnoreCase)) {
                    if ($queued.Add($href)) {
                        $htmlQueue.Enqueue($href)
                    }
                }
            }

            $capturedHtml += [pscustomobject]@{
                url = $url
                statusCode = $response.StatusCode
                contentType = $response.ContentType
                bytes = $response.Bytes.Length
                sha256 = Get-Sha256Hex $response.Bytes
                htmlFile = $htmlRelative
                textFile = if ([string]::IsNullOrWhiteSpace($extractedText)) { $null } else { $textRelative }
                textLength = $extractedText.Length
            }
        }
        else {
            $resourceIndex = @($capturedResources).Count + 1
            $safeName = ConvertTo-SafeName -Url $url -Index $resourceIndex
            $extension = Get-ExtensionForContentType -ContentType $response.ContentType
            $resourceRelative = "resources/$safeName$extension"
            Write-BytesFile -Path (Join-Path $captureDir $resourceRelative) -Value $response.Bytes

            $capturedResources += [pscustomobject]@{
                url = $url
                statusCode = $response.StatusCode
                contentType = $response.ContentType
                bytes = $response.Bytes.Length
                sha256 = Get-Sha256Hex $response.Bytes
                file = $resourceRelative
            }
        }
    }
}
finally {
    $script:HttpClient.Dispose()
    $handler.Dispose()
}

$restTextItems = @()
foreach ($collection in $restCollections) {
    foreach ($item in @($collection.items)) {
        $title = if ($null -ne $item.title -and $null -ne $item.title.rendered) { Convert-HtmlToText $item.title.rendered } else { '' }
        $content = if ($null -ne $item.content -and $null -ne $item.content.rendered) { Convert-HtmlToText $item.content.rendered } else { '' }
        $excerpt = if ($null -ne $item.excerpt -and $null -ne $item.excerpt.rendered) { Convert-HtmlToText $item.excerpt.rendered } else { '' }
        if ([string]::IsNullOrWhiteSpace($title) -and [string]::IsNullOrWhiteSpace($content) -and [string]::IsNullOrWhiteSpace($excerpt)) {
            continue
        }

        $slug = if ($null -ne $item.slug) { [string]$item.slug } elseif ($null -ne $item.id) { [string]$item.id } else { 'item' }
        $safeSlug = [regex]::Replace($slug.ToLowerInvariant(), '[^a-z0-9]+', '-').Trim('-')
        if ([string]::IsNullOrWhiteSpace($safeSlug)) {
            $safeSlug = 'item'
        }

        $fileName = "$($collection.name)-$safeSlug.txt"
        $relativePath = "rest-text/$fileName"
        $body = @(
            "sourceCollection: $($collection.name)"
            "id: $($item.id)"
            "slug: $slug"
            "link: $($item.link)"
            "title: $title"
            ''
            'excerpt:'
            $excerpt
            ''
            'content:'
            $content
        ) -join "`n"
        Write-Utf8File -Path (Join-Path $captureDir $relativePath) -Value $body

        $restTextItems += [pscustomobject]@{
            collection = $collection.name
            id = $item.id
            slug = $slug
            link = $item.link
            title = $title
            file = $relativePath
            contentTextLength = $content.Length
            excerptTextLength = $excerpt.Length
        }
    }
}

$collectionSummary = $restCollections | ForEach-Object {
    [pscustomobject]@{
        name = $_.name
        endpointUrl = $_.endpointUrl
        itemCount = $_.itemCount
        responses = $_.responses
    }
}

$manifest = [pscustomobject]@{
    schemaVersion = 1
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    sourceBaseUrl = $sourceBase
    userAgent = $SourceUserAgent
    requiredHtmlSeeds = $requiredHtmlSeeds
    restRoot = [pscustomobject]@{
        url = $restRootUrl
        statusCode = $restRootResponse.StatusCode
        contentType = $restRootResponse.ContentType
        bytes = $restRootResponse.Bytes.Length
        sha256 = Get-Sha256Hex $restRootResponse.Bytes
        file = 'rest/wp-json-root.json'
    }
    restTypes = [pscustomobject]@{
        url = $typesUrl
        statusCode = $typesResponse.StatusCode
        contentType = $typesResponse.ContentType
        bytes = $typesResponse.Bytes.Length
        sha256 = Get-Sha256Hex $typesResponse.Bytes
        file = 'rest/wp-v2-types.json'
    }
    restSearch = [pscustomobject]@{
        name = $restSearch.name
        endpointUrl = $restSearch.endpointUrl
        itemCount = $restSearch.itemCount
        responses = $restSearch.responses
    }
    restCollections = $collectionSummary
    htmlPages = $capturedHtml
    nonHtmlResources = $capturedResources
    restTextItems = $restTextItems
    counts = [pscustomobject]@{
        restCollections = @($restCollections).Count
        restTextItems = @($restTextItems).Count
        htmlPages = @($capturedHtml).Count
        htmlBytes = (@($capturedHtml) | Measure-Object -Property bytes -Sum).Sum
        nonHtmlResources = @($capturedResources).Count
        nonHtmlResourceBytes = (@($capturedResources) | Measure-Object -Property bytes -Sum).Sum
    }
}

Write-JsonFile -Path (Join-Path $captureDir 'manifest.json') -Value $manifest

[pscustomobject]@{
    CaptureDir = [System.IO.Path]::GetFullPath($captureDir)
    RestCollectionCount = @($restCollections).Count
    RestTextItemCount = @($restTextItems).Count
    HtmlPageCount = @($capturedHtml).Count
    HtmlBytes = $manifest.counts.htmlBytes
    NonHtmlResourceCount = @($capturedResources).Count
    NonHtmlResourceBytes = $manifest.counts.nonHtmlResourceBytes
}
