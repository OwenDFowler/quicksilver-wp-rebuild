[CmdletBinding()]
param(
    [string]$ThemeSlug = 'quicksilver-construction'
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$RepoFullPath = [System.IO.Path]::GetFullPath($RepoRoot)
$ThemePath = Join-Path $RepoRoot "theme\$ThemeSlug"
$ModelPath = Join-Path $RepoRoot 'content\site-model.json'
$MediaManifestPath = Join-Path $RepoRoot 'assets\source\media\media-manifest.json'
$GeneratedDataDir = Join-Path $ThemePath 'inc\generated'
$GeneratedDataPath = Join-Path $GeneratedDataDir 'site-data.php'
$GeneratedMediaDir = Join-Path $ThemePath 'assets\media\generated'
$ApprovedSourceMediaDir = Join-Path $RepoRoot 'assets\source\media\downloads'

function Assert-UnderRepo {
    param([string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (-not $fullPath.StartsWith($RepoFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to touch path outside repo: $fullPath"
    }
}

function Assert-File {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Missing required file: $Path"
    }
}

function Assert-UnderPath {
    param(
        [string]$Path,
        [string]$ParentPath,
        [string]$Description
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullParent = [System.IO.Path]::GetFullPath($ParentPath).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $fullPath.StartsWith($fullParent, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "$Description must resolve under $fullParent. Received: $fullPath"
    }
}

function As-Array {
    param($Value)

    if ($null -eq $Value) {
        return @()
    }

    return @($Value)
}

function Has-Value {
    param(
        $Values,
        [string]$Expected
    )

    return (As-Array $Values) -contains $Expected
}

function Read-UInt16BigEndian {
    param(
        [byte[]]$Bytes,
        [int]$Offset
    )

    $value = ([int]$Bytes[$Offset] -shl 8) -bor [int]$Bytes[$Offset + 1]
    return $value
}

function Read-UInt16LittleEndian {
    param(
        [byte[]]$Bytes,
        [int]$Offset
    )

    $value = [int]$Bytes[$Offset] -bor ([int]$Bytes[$Offset + 1] -shl 8)
    return $value
}

function Read-UInt24LittleEndian {
    param(
        [byte[]]$Bytes,
        [int]$Offset
    )

    $value = [int]$Bytes[$Offset] -bor ([int]$Bytes[$Offset + 1] -shl 8) -bor ([int]$Bytes[$Offset + 2] -shl 16)
    return $value
}

function Read-UInt32BigEndian {
    param(
        [byte[]]$Bytes,
        [int]$Offset
    )

    $value = ([uint32]$Bytes[$Offset] -shl 24) -bor ([uint32]$Bytes[$Offset + 1] -shl 16) -bor ([uint32]$Bytes[$Offset + 2] -shl 8) -bor [uint32]$Bytes[$Offset + 3]
    return $value
}

function Read-UInt32LittleEndian {
    param(
        [byte[]]$Bytes,
        [int]$Offset
    )

    $value = [uint32]$Bytes[$Offset] -bor ([uint32]$Bytes[$Offset + 1] -shl 8) -bor ([uint32]$Bytes[$Offset + 2] -shl 16) -bor ([uint32]$Bytes[$Offset + 3] -shl 24)
    return $value
}

function Read-ImageDimensions {
    param([string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 12) {
        throw "Image file is too small to read dimensions: $Path"
    }

    if ($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xD8) {
        $offset = 2
        while ($offset + 9 -lt $bytes.Length) {
            while ($offset -lt $bytes.Length -and $bytes[$offset] -ne 0xFF) {
                $offset++
            }

            while ($offset -lt $bytes.Length -and $bytes[$offset] -eq 0xFF) {
                $offset++
            }

            if ($offset -ge $bytes.Length) {
                break
            }

            $marker = $bytes[$offset]
            $offset++
            if ($marker -eq 0xD9 -or $marker -eq 0xDA) {
                break
            }

            if ($offset + 1 -ge $bytes.Length) {
                break
            }

            $segmentLength = Read-UInt16BigEndian -Bytes $bytes -Offset $offset
            if ($segmentLength -lt 2 -or $offset + $segmentLength -gt $bytes.Length) {
                break
            }

            $sofMarkers = @(0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF)
            if ($sofMarkers -contains $marker) {
                return [pscustomobject]@{
                    width = Read-UInt16BigEndian -Bytes $bytes -Offset ($offset + 5)
                    height = Read-UInt16BigEndian -Bytes $bytes -Offset ($offset + 3)
                }
            }

            $offset += $segmentLength
        }
    }

    $ascii = [System.Text.Encoding]::ASCII
    if ($bytes.Length -ge 24 -and $ascii.GetString($bytes, 0, 4) -eq 'RIFF' -and $ascii.GetString($bytes, 8, 4) -eq 'WEBP') {
        $format = $ascii.GetString($bytes, 12, 4)
        if ($format -eq 'VP8X' -and $bytes.Length -ge 30) {
            return [pscustomobject]@{
                width = (Read-UInt24LittleEndian -Bytes $bytes -Offset 24) + 1
                height = (Read-UInt24LittleEndian -Bytes $bytes -Offset 27) + 1
            }
        }

        if ($format -eq 'VP8L' -and $bytes.Length -ge 25) {
            $b0 = $bytes[21]
            $b1 = $bytes[22]
            $b2 = $bytes[23]
            $b3 = $bytes[24]
            return [pscustomobject]@{
                width = 1 + (($b1 -band 0x3F) -shl 8) + $b0
                height = 1 + (($b3 -band 0x0F) -shl 10) + ($b2 -shl 2) + (($b1 -band 0xC0) -shr 6)
            }
        }

        if ($format -eq 'VP8 ' -and $bytes.Length -ge 30) {
            return [pscustomobject]@{
                width = (Read-UInt16LittleEndian -Bytes $bytes -Offset 26) -band 0x3FFF
                height = (Read-UInt16LittleEndian -Bytes $bytes -Offset 28) -band 0x3FFF
            }
        }
    }

    if ($bytes.Length -ge 24 -and $bytes[0] -eq 0x89 -and $ascii.GetString($bytes, 1, 3) -eq 'PNG') {
        return [pscustomobject]@{
            width = Read-UInt32BigEndian -Bytes $bytes -Offset 16
            height = Read-UInt32BigEndian -Bytes $bytes -Offset 20
        }
    }

    throw "Unsupported image format for dimension read: $Path"
}

function Get-FirstRequired {
    param(
        $Values,
        [string]$Description
    )

    $items = As-Array $Values
    if ($items.Count -eq 0) {
        throw "Missing required $Description."
    }

    return $items[0]
}

function Get-AssetAlt {
    param($Asset)

    $alts = As-Array $Asset.appearances |
        ForEach-Object { $_.alt } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Unique

    if ((As-Array $alts).Count -gt 0) {
        return (As-Array $alts)[0]
    }

    if (Has-Value $Asset.inferredRoles 'logo/media reference') {
        return 'QuickSilver Construction'
    }

    if (Has-Value $Asset.inferredRoles 'homepage hero/slider') {
        return 'QuickSilver Construction project photo'
    }

    return 'QuickSilver Construction work photo'
}

function Copy-ThemeAsset {
    param(
        $Asset,
        [string]$Slot
    )

    if ([string]::IsNullOrWhiteSpace($Asset.localPath)) {
        throw "Media asset for slot $Slot is missing localPath."
    }

    $sourcePath = Join-Path $RepoRoot $Asset.localPath
    Assert-UnderPath -Path $sourcePath -ParentPath $ApprovedSourceMediaDir -Description "Theme media source"
    Assert-File $sourcePath

    $fileName = Split-Path -Leaf $Asset.localPath
    $destinationPath = Join-Path $GeneratedMediaDir $fileName
    Assert-UnderRepo $destinationPath
    Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
    $dimensions = Read-ImageDimensions -Path $sourcePath

    [pscustomobject]@{
        slot = $Slot
        path = "assets/media/generated/$fileName"
        alt = Get-AssetAlt $Asset
        width = $dimensions.width
        height = $dimensions.height
        sourceLocalPath = $Asset.localPath
        priority = $Asset.priority
        roles = As-Array $Asset.inferredRoles
        sourcePageSlugs = As-Array $Asset.sourcePageSlugs
        sha256 = $Asset.sha256
    }
}

Assert-File $ModelPath
Assert-File $MediaManifestPath

if (-not (Test-Path -LiteralPath $ThemePath -PathType Container)) {
    throw "Missing theme directory: $ThemePath"
}

$siteModel = Get-Content -LiteralPath $ModelPath -Raw | ConvertFrom-Json
$mediaManifest = Get-Content -LiteralPath $MediaManifestPath -Raw | ConvertFrom-Json

$homePage = Get-FirstRequired (@($siteModel.pages | Where-Object { $_.pageKey -eq 'home' })) 'home page model'
$homeSections = As-Array $homePage.sections
if ($homeSections.Count -eq 0) {
    throw "Home page model must contain at least one section."
}

$requiredIdentityFields = @('businessName', 'licenseText', 'phone', 'email', 'primaryCta', 'footerSummary', 'copyrightText')
foreach ($field in $requiredIdentityFields) {
    if ($null -eq $siteModel.siteIdentity.$field) {
        throw "siteIdentity.$field is required."
    }
}

$routeByPageKey = @{}
foreach ($route in As-Array $siteModel.canonicalRoutes) {
    if (-not [string]::IsNullOrWhiteSpace($route.pageKey) -and -not [string]::IsNullOrWhiteSpace($route.route)) {
        $routeByPageKey[$route.pageKey] = $route.route
    }
}

foreach ($navItem in As-Array $siteModel.navigation) {
    if (-not $routeByPageKey.ContainsKey($navItem.pageKey)) {
        throw "Navigation item '$($navItem.label)' references missing route for pageKey '$($navItem.pageKey)'."
    }
}

$allAssets = As-Array $mediaManifest.assets
if ($allAssets.Count -eq 0) {
    throw "Media manifest does not contain assets."
}

$logoAsset = Get-FirstRequired (
    $allAssets |
        Where-Object { Has-Value $_.inferredRoles 'logo/media reference' } |
        Sort-Object localPath
) 'logo/media reference asset'

$heroAssets = @(
    $allAssets |
        Where-Object {
            $_.priority -eq 'must-recreate' -and
            (Has-Value $_.sourcePageSlugs 'home') -and
            (Has-Value $_.inferredRoles 'homepage hero/slider')
        } |
        Sort-Object localPath |
        Select-Object -First 3
)

if ($heroAssets.Count -eq 0) {
    throw "No homepage hero assets were found in the media manifest."
}

$homeVisualAssets = @(
    $allAssets |
        Where-Object {
            (Has-Value $_.sourcePageSlugs 'home') -and
            (Has-Value $_.inferredRoles 'content image') -and
            -not (Has-Value $_.inferredRoles 'homepage hero/slider')
        } |
        Sort-Object priority, localPath |
        Select-Object -First 4
)

if ($homeVisualAssets.Count -lt 2) {
    throw "At least two homepage content image assets are required by the theme template."
}

Assert-UnderRepo $GeneratedDataDir
Assert-UnderRepo $GeneratedMediaDir
New-Item -ItemType Directory -Force -Path $GeneratedDataDir | Out-Null
New-Item -ItemType Directory -Force -Path $GeneratedMediaDir | Out-Null

Get-ChildItem -LiteralPath $GeneratedMediaDir -File | Remove-Item -Force

$logo = Copy-ThemeAsset -Asset $logoAsset -Slot 'logo'
$hero = @($heroAssets | ForEach-Object { Copy-ThemeAsset -Asset $_ -Slot 'home.hero' })
$homeVisuals = @($homeVisualAssets | ForEach-Object { Copy-ThemeAsset -Asset $_ -Slot 'home.visual' })

$themeData = [pscustomobject]@{
    schemaVersion = 1
    sourceModelPath = 'content/site-model.json'
    sourceMediaManifestPath = 'assets/source/media/media-manifest.json'
    siteIdentity = $siteModel.siteIdentity
    canonicalRoutes = $siteModel.canonicalRoutes
    routeByPageKey = $routeByPageKey
    navigation = $siteModel.navigation
    pages = $siteModel.pages
    homePage = $homePage
    media = [pscustomobject]@{
        logo = $logo
        homeHero = $hero
        homeVisuals = $homeVisuals
    }
}

$json = $themeData | ConvertTo-Json -Depth 100
$php = @"
<?php
// Generated by scripts/generate-theme-data.ps1. Commit regenerated output with theme changes.
if (!defined('ABSPATH')) {
    exit;
}

return json_decode(<<<'JSON'
$json
JSON, true, 512, JSON_THROW_ON_ERROR);
"@

Assert-UnderRepo $GeneratedDataPath
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($GeneratedDataPath, $php, $utf8NoBom)

[pscustomobject]@{
    GeneratedData = $GeneratedDataPath
    GeneratedMediaDir = $GeneratedMediaDir
    HeroAssetCount = $hero.Count
    HomeVisualAssetCount = $homeVisuals.Count
    LogoAsset = $logo.path
}
