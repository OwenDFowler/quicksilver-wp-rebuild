[CmdletBinding()]
param(
    [string]$ThemeSlug = 'quicksilver-construction'
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$RepoFullPath = [System.IO.Path]::GetFullPath($RepoRoot)
$CanonicalThemeSlug = 'quicksilver-construction'
$ThemePath = Join-Path $RepoRoot "theme\$ThemeSlug"
$ModelPath = Join-Path $RepoRoot 'content\site-model.json'
$MediaManifestPath = Join-Path $RepoRoot 'assets\source\media\media-manifest.json'
$GeneratedDataDir = Join-Path $ThemePath 'inc\generated'
$GeneratedDataPath = Join-Path $GeneratedDataDir 'site-data.php'
$GeneratedMediaDir = Join-Path $ThemePath 'assets\media\generated'
$ApprovedSourceMediaDir = Join-Path $RepoRoot 'assets\source\media\downloads'

if ($ThemeSlug -cne $CanonicalThemeSlug) {
    throw "Unsupported QuickSilver theme slug '$ThemeSlug'. This repo owns one theme: $CanonicalThemeSlug."
}

function Assert-UnderRepo {
    param([string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $repoRootWithSeparator = $RepoFullPath.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if ($fullPath -ne $RepoFullPath -and -not $fullPath.StartsWith($repoRootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
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

function Get-RequiredStringValue {
    param(
        $Value,
        [string]$Description
    )

    if (-not ($Value -is [string]) -or [string]::IsNullOrWhiteSpace($Value)) {
        throw "$Description must be a non-empty string."
    }

    return $Value
}

function Assert-PageKey {
    param(
        [string]$Value,
        [string]$Description
    )

    if ($Value -notmatch '^[a-z][a-z0-9-]*$') {
        throw "$Description must be a lowercase page key. Received: $Value"
    }
}

function Assert-RoutePath {
    param(
        [string]$Value,
        [string]$Description
    )

    if ($Value -notmatch '^/[a-z0-9-]*/?$' -or $Value.Contains('..') -or $Value.Contains('//')) {
        throw "$Description must be a clean local route. Received: $Value"
    }
}

function Assert-RuntimeHref {
    param(
        [string]$Value,
        [string]$Description
    )

    if ($Value -match '^(https://|mailto:|tel:|/)' -and -not $Value.Contains('..')) {
        return
    }

    throw "$Description must use https:, mailto:, tel:, or a local absolute route. Received: $Value"
}

function Get-RequiredAssetByLocalPath {
    param(
        $Assets,
        [string]$LocalPath,
        [string]$Description
    )

    $asset = Get-FirstRequired (
        As-Array $Assets |
            Where-Object { $_.localPath -eq $LocalPath }
    ) $Description

    return $asset
}

function Get-RequiredHomeSection {
    param(
        [array]$Sections,
        [string]$SectionId
    )

    return Get-FirstRequired (
        As-Array $Sections |
            Where-Object { $_.id -eq $SectionId }
    ) "home section '$SectionId'"
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
        [string]$Slot,
        [string]$AltOverride = $null,
        [bool]$Decorative = $false
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
        alt = if ($Decorative) { '' } elseif ($null -ne $AltOverride) { $AltOverride } else { Get-AssetAlt $Asset }
        decorative = $Decorative
        width = $dimensions.width
        height = $dimensions.height
    }
}

function ConvertTo-RuntimeCta {
    param($Cta)

    $label = Get-RequiredStringValue -Value $Cta.label -Description 'Runtime CTA label'

    $runtimeCta = [ordered]@{
        label = $label
    }

    if (-not [string]::IsNullOrWhiteSpace($Cta.targetPageKey)) {
        $pageKey = Get-RequiredStringValue -Value $Cta.targetPageKey -Description "Runtime CTA '$label' targetPageKey"
        Assert-PageKey -Value $pageKey -Description "Runtime CTA '$label' targetPageKey"
        $runtimeCta.targetPageKey = $pageKey
    }
    elseif (-not [string]::IsNullOrWhiteSpace($Cta.href)) {
        $href = Get-RequiredStringValue -Value $Cta.href -Description "Runtime CTA '$label' href"
        Assert-RuntimeHref -Value $href -Description "Runtime CTA '$label' href"
        $runtimeCta.href = $href
    }
    else {
        throw "Runtime CTA '$label' requires targetPageKey or href."
    }

    return [pscustomobject]$runtimeCta
}

function ConvertTo-RuntimeSectionItem {
    param($Item)

    if ($Item -is [string]) {
        if ([string]::IsNullOrWhiteSpace($Item)) {
            throw 'Runtime section string item must be non-empty.'
        }

        return $Item
    }

    $runtimeItem = [ordered]@{}
    foreach ($key in @('mediaSlotKey', 'title', 'body')) {
        if ($null -ne $Item.$key) {
            $runtimeItem[$key] = Get-RequiredStringValue -Value $Item.$key -Description "Runtime section item $key"
        }
    }

    if ($runtimeItem.Count -eq 0) {
        throw 'Runtime section item did not contain any approved fields.'
    }

    return [pscustomobject]$runtimeItem
}

function ConvertTo-RuntimeSection {
    param($Section)

    $id = Get-RequiredStringValue -Value $Section.id -Description 'Runtime section id'
    $type = Get-RequiredStringValue -Value $Section.type -Description "Runtime section '$id' type"

    $runtimeSection = [ordered]@{
        id = $id
        type = $type
    }

    foreach ($key in @('heading', 'body', 'text', 'status', 'approvedPlugin', 'submissionEndpoint', 'renderInstruction')) {
        if ($null -ne $Section.$key) {
            $runtimeSection[$key] = Get-RequiredStringValue -Value $Section.$key -Description "Runtime section '$id' $key"
        }
    }

    if ($null -ne $Section.collectsUserData) {
        if (-not ($Section.collectsUserData -is [bool])) {
            throw "Runtime section '$id' collectsUserData must be boolean."
        }

        $runtimeSection.collectsUserData = $Section.collectsUserData
    }

    if ($null -ne $Section.ctas) {
        $runtimeSection.ctas = @(As-Array $Section.ctas | ForEach-Object { ConvertTo-RuntimeCta $_ })
    }

    if ($null -ne $Section.items) {
        $runtimeSection.items = @(As-Array $Section.items | ForEach-Object { ConvertTo-RuntimeSectionItem $_ })
    }

    return [pscustomobject]$runtimeSection
}

function ConvertTo-RuntimePage {
    param($Page)

    $pageKey = Get-RequiredStringValue -Value $Page.pageKey -Description 'Runtime page pageKey'
    Assert-PageKey -Value $pageKey -Description 'Runtime page pageKey'
    $title = Get-RequiredStringValue -Value $Page.title -Description "Runtime page '$pageKey' title"
    $canonicalRoute = Get-RequiredStringValue -Value $Page.canonicalRoute -Description "Runtime page '$pageKey' canonicalRoute"
    Assert-RoutePath -Value $canonicalRoute -Description "Runtime page '$pageKey' canonicalRoute"
    $templateRole = Get-RequiredStringValue -Value $Page.templateRole -Description "Runtime page '$pageKey' templateRole"

    [pscustomobject]@{
        pageKey = $pageKey
        title = $title
        canonicalRoute = $canonicalRoute
        templateRole = $templateRole
        sections = @(As-Array $Page.sections | ForEach-Object { ConvertTo-RuntimeSection $_ })
    }
}

function ConvertTo-RuntimeNavigationItem {
    param($Item)

    $label = Get-RequiredStringValue -Value $Item.label -Description 'Runtime navigation label'
    $pageKey = Get-RequiredStringValue -Value $Item.pageKey -Description "Runtime navigation '$label' pageKey"
    Assert-PageKey -Value $pageKey -Description "Runtime navigation '$label' pageKey"

    [pscustomobject]@{
        label = $label
        pageKey = $pageKey
    }
}

function Assert-GeneratedRuntimeData {
    param([string]$Json)

    $blockedPatterns = @(
        '"source[A-Za-z0-9_]*"\s*:',
        '"assetRefs"\s*:',
        '"localPath"\s*:',
        '"sourceLocalPath"\s*:',
        '"priority"\s*:',
        '"roles"\s*:',
        '"sha256"\s*:',
        'assets/source',
        'zti\.sad\.mybluehost\.me'
    )

    foreach ($pattern in $blockedPatterns) {
        if ($Json -match $pattern) {
            throw "Generated runtime theme data contains blocked provenance pattern: $pattern"
        }
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
    $pageKey = Get-RequiredStringValue -Value $route.pageKey -Description 'canonicalRoutes.pageKey'
    Assert-PageKey -Value $pageKey -Description 'canonicalRoutes.pageKey'
    $routePath = Get-RequiredStringValue -Value $route.route -Description "canonicalRoutes.$pageKey.route"
    Assert-RoutePath -Value $routePath -Description "canonicalRoutes.$pageKey.route"
    $routeByPageKey[$pageKey] = $routePath
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

$homeMediaSlots = $homePage.mediaSlots
if ($null -eq $homeMediaSlots) {
    throw "Home page model must define mediaSlots for still-design assets."
}

$requiredHomeStillSlotKeys = @('qualityPrimary', 'qualityInset', 'ctaBackground')
$valuesSection = Get-RequiredHomeSection -Sections $homeSections -SectionId 'home.values-band'
$valuesItems = As-Array $valuesSection.items
if ($valuesItems.Count -eq 0) {
    throw "Home values section must contain at least one item."
}

$requiredHomeValueSlotKeys = @()
foreach ($item in $valuesItems) {
    if ([string]::IsNullOrWhiteSpace($item.mediaSlotKey)) {
        throw "Every home values item must define mediaSlotKey."
    }

    $requiredHomeValueSlotKeys += $item.mediaSlotKey
}

$allRequiredHomeSlotKeys = @($requiredHomeStillSlotKeys + $requiredHomeValueSlotKeys | Select-Object -Unique)
foreach ($slotKey in $allRequiredHomeSlotKeys) {
    if ($null -eq $homeMediaSlots.$slotKey) {
        throw "Home page mediaSlots.$slotKey is required."
    }

    if ([string]::IsNullOrWhiteSpace($homeMediaSlots.$slotKey.localPath)) {
        throw "Home page mediaSlots.$slotKey.localPath is required."
    }

    if ($null -eq $homeMediaSlots.$slotKey.decorative) {
        throw "Home page mediaSlots.$slotKey.decorative is required."
    }

    if (-not [bool]$homeMediaSlots.$slotKey.decorative -and [string]::IsNullOrWhiteSpace($homeMediaSlots.$slotKey.alt)) {
        throw "Home page mediaSlots.$slotKey.alt is required for non-decorative assets."
    }
}

Assert-UnderRepo $GeneratedDataDir
Assert-UnderRepo $GeneratedMediaDir
New-Item -ItemType Directory -Force -Path $GeneratedDataDir | Out-Null
New-Item -ItemType Directory -Force -Path $GeneratedMediaDir | Out-Null

Get-ChildItem -LiteralPath $GeneratedMediaDir -File | Remove-Item -Force

$logo = Copy-ThemeAsset -Asset $logoAsset -Slot 'logo' -AltOverride 'QuickSilver Construction'
$hero = @($heroAssets | ForEach-Object { Copy-ThemeAsset -Asset $_ -Slot 'home.hero' -Decorative $true })
$homeStill = [ordered]@{}
foreach ($slotKey in $requiredHomeStillSlotKeys) {
    $slot = $homeMediaSlots.$slotKey
    $asset = Get-RequiredAssetByLocalPath -Assets $allAssets -LocalPath $slot.localPath -Description "homepage still-design asset '$slotKey'"
    $homeStill[$slotKey] = Copy-ThemeAsset -Asset $asset -Slot "home.$slotKey" -AltOverride $slot.alt -Decorative ([bool]$slot.decorative)
}

$homeValues = [ordered]@{}
foreach ($slotKey in $requiredHomeValueSlotKeys) {
    $slot = $homeMediaSlots.$slotKey
    $asset = Get-RequiredAssetByLocalPath -Assets $allAssets -LocalPath $slot.localPath -Description "homepage values asset '$slotKey'"
    $homeValues[$slotKey] = Copy-ThemeAsset -Asset $asset -Slot "home.$slotKey" -AltOverride $slot.alt -Decorative ([bool]$slot.decorative)
}

$runtimeHomePage = ConvertTo-RuntimePage $homePage
$runtimeNavigation = @(As-Array $siteModel.navigation | ForEach-Object { ConvertTo-RuntimeNavigationItem $_ })

$themeData = [pscustomobject]@{
    schemaVersion = 1
    siteIdentity = $siteModel.siteIdentity
    routeByPageKey = $routeByPageKey
    navigation = $runtimeNavigation
    homePage = $runtimeHomePage
    media = [pscustomobject]@{
        logo = $logo
        homeHero = $hero
        homeStill = [pscustomobject]$homeStill
        homeValues = [pscustomobject]$homeValues
    }
}

$json = $themeData | ConvertTo-Json -Depth 100
Assert-GeneratedRuntimeData -Json $json
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
    HomeStillAssetSlots = @($homeStill.Keys)
    HomeValueAssetSlots = @($homeValues.Keys)
    LogoAsset = $logo.path
}
