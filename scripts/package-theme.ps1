[CmdletBinding()]
param(
    [string]$ThemeSlug = 'quicksilver-construction'
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$ThemePath = Join-Path $RepoRoot "theme\$ThemeSlug"
$StylePath = Join-Path $ThemePath 'style.css'
$IndexPath = Join-Path $ThemePath 'index.php'
$GeneratedDataPath = Join-Path $ThemePath 'inc\generated\site-data.php'
$RepoFullPath = [System.IO.Path]::GetFullPath($RepoRoot)

function Assert-UnderRepo {
    param([string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (-not $fullPath.StartsWith($RepoFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to touch path outside repo: $fullPath"
    }
}

if (-not (Test-Path -LiteralPath $StylePath)) {
    throw "Missing required WordPress theme file: $StylePath"
}

if (-not (Test-Path -LiteralPath $IndexPath)) {
    throw "Missing required WordPress theme file: $IndexPath"
}

& $PSScriptRoot\generate-theme-data.ps1 -ThemeSlug $ThemeSlug | Out-Null

if (-not (Test-Path -LiteralPath $GeneratedDataPath -PathType Leaf)) {
    throw "Missing generated theme data file: $GeneratedDataPath"
}

$DistPath = Join-Path $RepoRoot 'dist'
New-Item -ItemType Directory -Force -Path $DistPath | Out-Null

$ZipPath = Join-Path $DistPath "$ThemeSlug.zip"
if (Test-Path -LiteralPath $ZipPath) {
    Assert-UnderRepo $ZipPath
    Remove-Item -LiteralPath $ZipPath
}

$PackageRoot = Join-Path $RepoRoot '.tmp\theme-package'
$PackageThemePath = Join-Path $PackageRoot $ThemeSlug

Assert-UnderRepo $PackageRoot
if (Test-Path -LiteralPath $PackageRoot) {
    Remove-Item -LiteralPath $PackageRoot -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $PackageThemePath | Out-Null

$ThemeItems = Get-ChildItem -LiteralPath $ThemePath -Force
foreach ($item in $ThemeItems) {
    Copy-Item -LiteralPath $item.FullName -Destination $PackageThemePath -Recurse -Force
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($PackageRoot, $ZipPath)

Remove-Item -LiteralPath $PackageRoot -Recurse -Force

Get-Item -LiteralPath $ZipPath
