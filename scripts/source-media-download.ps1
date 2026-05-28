[CmdletBinding()]
param(
    [string]$AssetManifestPath,
    [string]$OutputDir,
    [string]$OutputManifestPath,
    [string[]]$Priorities = @('must-recreate', 'candidate'),
    [int]$DelayMilliseconds = 2500,
    [int]$TimeoutSeconds = 60,
    [switch]$IncludeReference
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$RepoFullPath = [System.IO.Path]::GetFullPath($RepoRoot)
$SourceUserAgent = 'QuickSilverSourceMediaDownload/1.0 (+public-source-site-rebuild)'
$AllowedHosts = @(
    'zti.sad.mybluehost.me',
    'i0.wp.com'
)

if ([string]::IsNullOrWhiteSpace($AssetManifestPath)) {
    $AssetManifestPath = Join-Path $RepoRoot 'assets\source\inventory\asset-manifest.json'
}

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $RepoRoot 'assets\source\media'
}

if ([string]::IsNullOrWhiteSpace($OutputManifestPath)) {
    $OutputManifestPath = Join-Path $OutputDir 'media-manifest.json'
}

function Assert-UnderRepo {
    param([string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (-not $fullPath.StartsWith($RepoFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to write outside repo: $fullPath"
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

function ConvertTo-SafeFilePart {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return 'asset'
    }

    $safe = $Value.ToLowerInvariant()
    $safe = [regex]::Replace($safe, '[^a-z0-9]+', '-')
    $safe = $safe.Trim('-')
    if ([string]::IsNullOrWhiteSpace($safe)) {
        return 'asset'
    }

    if ($safe.Length -gt 64) {
        return $safe.Substring(0, 64).Trim('-')
    }

    return $safe
}

function Get-SourceAssetUrl {
    param([string]$Url)

    $uri = [System.Uri]$Url
    if ($uri.Scheme -ne 'https') {
        throw "Asset URL must use https: $Url"
    }

    if ($AllowedHosts -notcontains $uri.Host) {
        throw "Refusing to download from unapproved host '$($uri.Host)': $Url"
    }

    if ($uri.Host -eq 'i0.wp.com') {
        $originPath = $uri.AbsolutePath.TrimStart('/')
        $slashIndex = $originPath.IndexOf('/')
        if ($slashIndex -le 0) {
            throw "Malformed i0.wp.com asset URL: $Url"
        }

        $originHost = $originPath.Substring(0, $slashIndex)
        $originAssetPath = $originPath.Substring($slashIndex)
        if ($originHost -ne 'zti.sad.mybluehost.me') {
            throw "Refusing to normalize i0.wp.com asset for unapproved origin '$originHost': $Url"
        }

        return "https://$originHost$originAssetPath"
    }

    return $uri.GetLeftPart([System.UriPartial]::Path)
}

function Get-ExtensionForContent {
    param(
        [string]$ContentType,
        [string]$Url
    )

    $contentTypeValue = ''
    if (-not [string]::IsNullOrWhiteSpace($ContentType)) {
        $contentTypeValue = $ContentType.Split(';')[0].Trim().ToLowerInvariant()
    }

    switch ($contentTypeValue) {
        'image/jpeg' { return '.jpg' }
        'image/png' { return '.png' }
        'image/webp' { return '.webp' }
        'image/gif' { return '.gif' }
        'image/svg+xml' { return '.svg' }
    }

    $pathExtension = [System.IO.Path]::GetExtension(([System.Uri]$Url).AbsolutePath)
    if ([string]::IsNullOrWhiteSpace($pathExtension)) {
        throw "Could not determine file extension for $Url with content type '$ContentType'."
    }

    return $pathExtension.ToLowerInvariant()
}

function Get-AssetPriorityRank {
    param([string]$Priority)

    switch ($Priority) {
        'must-recreate' { return 0 }
        'candidate' { return 1 }
        'reference' { return 2 }
        default { return 3 }
    }
}

function Invoke-AssetDownload {
    param(
        [System.Net.Http.HttpClient]$Client,
        [string]$Url
    )

    if ($script:RequestCount -gt 0 -and $DelayMilliseconds -gt 0) {
        Start-Sleep -Milliseconds $DelayMilliseconds
    }

    $script:RequestCount += 1
    $response = $Client.GetAsync($Url).GetAwaiter().GetResult()
    try {
        $statusCode = [int]$response.StatusCode
        if ($statusCode -lt 200 -or $statusCode -gt 299) {
            throw "HTTP $statusCode"
        }

        $bytes = $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
        if ($bytes.Length -le 0) {
            throw 'empty response body'
        }

        $contentType = ''
        if ($null -ne $response.Content.Headers.ContentType) {
            $contentType = $response.Content.Headers.ContentType.ToString()
        }

        if (-not $contentType.StartsWith('image/', [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "expected image content, got '$contentType'"
        }

        return [pscustomobject]@{
            Url = $Url
            Bytes = $bytes
            ContentType = $contentType
        }
    }
    finally {
        $response.Dispose()
    }
}

function Get-Sha256Hex {
    param([byte[]]$Bytes)

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha256.ComputeHash($Bytes)
        return ([System.BitConverter]::ToString($hash)).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha256.Dispose()
    }
}

Assert-UnderRepo $AssetManifestPath
Assert-UnderRepo $OutputDir
Assert-UnderRepo $OutputManifestPath

if (-not (Test-Path -LiteralPath $AssetManifestPath)) {
    throw "Asset manifest not found: $AssetManifestPath"
}

if ($DelayMilliseconds -lt 0) {
    throw 'DelayMilliseconds cannot be negative.'
}

if ($TimeoutSeconds -lt 1) {
    throw 'TimeoutSeconds must be at least 1.'
}

$parsedManifest = Get-Content -LiteralPath $AssetManifestPath -Raw | ConvertFrom-Json
$manifestItems = @()
foreach ($item in $parsedManifest) {
    $manifestItems += $item
}

if ($manifestItems.Count -eq 0) {
    throw "Asset manifest is empty: $AssetManifestPath"
}

$selectedPriorities = @($Priorities | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
if ($IncludeReference -and $selectedPriorities -notcontains 'reference') {
    $selectedPriorities += 'reference'
}

if ($selectedPriorities.Count -eq 0) {
    throw 'At least one priority is required.'
}

$selectedItems = @($manifestItems | Where-Object { $selectedPriorities -contains $_.priority })
if ($selectedItems.Count -eq 0) {
    throw "No assets matched priorities: $($selectedPriorities -join ', ')"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$downloadRoot = Join-Path $OutputDir 'downloads'
Assert-UnderRepo $downloadRoot
New-Item -ItemType Directory -Force -Path $downloadRoot | Out-Null

$groups = @{}
foreach ($item in $selectedItems) {
    $sourceAssetUrl = Get-SourceAssetUrl $item.url
    if (-not $groups.ContainsKey($sourceAssetUrl)) {
        $groups[$sourceAssetUrl] = @()
    }
    $groups[$sourceAssetUrl] = @($groups[$sourceAssetUrl] + $item)
}

Add-Type -AssemblyName System.Net.Http

$handler = [System.Net.Http.HttpClientHandler]::new()
$handler.AllowAutoRedirect = $true
$client = [System.Net.Http.HttpClient]::new($handler)
$client.Timeout = [TimeSpan]::FromSeconds($TimeoutSeconds)
$client.DefaultRequestHeaders.UserAgent.ParseAdd($SourceUserAgent)

$script:RequestCount = 0
$downloaded = @()
$downloadedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
$index = 0

try {
    foreach ($sourceAssetUrl in ($groups.Keys | Sort-Object)) {
        $index += 1
        $appearances = @($groups[$sourceAssetUrl])
        $priority = @($appearances | Sort-Object { Get-AssetPriorityRank $_.priority } | Select-Object -First 1).priority
        $roles = @($appearances.inferredRole | Sort-Object -Unique)
        $pageSlugs = @($appearances.sourcePageSlug | Sort-Object -Unique)
        $sourceUrls = @($appearances.url | Sort-Object -Unique)

        try {
            $result = Invoke-AssetDownload -Client $client -Url $sourceAssetUrl
        }
        catch {
            throw "Failed to download source asset '$sourceAssetUrl': $($_.Exception.Message)"
        }

        $extension = Get-ExtensionForContent -ContentType $result.ContentType -Url $result.Url
        $leafBase = [System.IO.Path]::GetFileNameWithoutExtension(([System.Uri]$sourceAssetUrl).AbsolutePath)
        $rolePart = ConvertTo-SafeFilePart ($roles -join '-')
        $leafPart = ConvertTo-SafeFilePart $leafBase
        $priorityPart = ConvertTo-SafeFilePart $priority
        $fileName = ('{0:d3}-{1}-{2}{3}' -f $index, $rolePart, $leafPart, $extension)
        $priorityDir = Join-Path $downloadRoot $priorityPart
        Assert-UnderRepo $priorityDir
        New-Item -ItemType Directory -Force -Path $priorityDir | Out-Null

        $localPath = Join-Path $priorityDir $fileName
        Assert-UnderRepo $localPath
        [System.IO.File]::WriteAllBytes($localPath, $result.Bytes)

        $relativeLocalPath = [System.IO.Path]::GetFullPath($localPath).Substring($RepoFullPath.Length + 1).Replace('\', '/')
        $downloaded += [pscustomobject]@{
            localPath = $relativeLocalPath
            sourceAssetUrl = $sourceAssetUrl
            downloadedUrl = $result.Url
            sourceUrls = $sourceUrls
            sourcePageSlugs = $pageSlugs
            priority = $priority
            inferredRoles = $roles
            contentType = $result.ContentType
            bytes = $result.Bytes.Length
            sha256 = Get-Sha256Hex $result.Bytes
            appearances = $appearances
            downloadedAtUtc = $downloadedAtUtc
        }
    }
}
finally {
    $client.Dispose()
    $handler.Dispose()
}

$summary = [pscustomobject]@{
    generatedAtUtc = $downloadedAtUtc
    assetManifestPath = [System.IO.Path]::GetFullPath($AssetManifestPath).Substring($RepoFullPath.Length + 1).Replace('\', '/')
    outputDir = [System.IO.Path]::GetFullPath($OutputDir).Substring($RepoFullPath.Length + 1).Replace('\', '/')
    selectedPriorities = $selectedPriorities
    allowedHosts = $AllowedHosts
    delayMilliseconds = $DelayMilliseconds
    requestCount = $script:RequestCount
    downloadedAssetCount = @($downloaded).Count
    totalBytes = (@($downloaded) | Measure-Object -Property bytes -Sum).Sum
    assets = $downloaded
}

Write-JsonFile -Path $OutputManifestPath -Value $summary

[pscustomobject]@{
    Manifest = [System.IO.Path]::GetFullPath($OutputManifestPath)
    DownloadedAssetCount = $summary.downloadedAssetCount
    TotalBytes = $summary.totalBytes
    RequestCount = $summary.requestCount
    DelayMilliseconds = $DelayMilliseconds
    Priorities = ($selectedPriorities -join ', ')
}
