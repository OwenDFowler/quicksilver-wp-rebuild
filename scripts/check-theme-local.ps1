[CmdletBinding()]
param(
    [string]$ThemeSlug = 'quicksilver-construction',
    [string]$WordPressImage
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$RepoFullPath = [System.IO.Path]::GetFullPath($RepoRoot)
$CanonicalThemeSlug = 'quicksilver-construction'
$ThemePath = Join-Path $RepoRoot "theme\$ThemeSlug"
$ThemeFullPath = [System.IO.Path]::GetFullPath($ThemePath)
$GeneratedDataPath = Join-Path $ThemePath 'inc\generated\site-data.php'
$GeneratedDataDir = Join-Path $ThemePath 'inc\generated'
$GeneratedMediaDir = Join-Path $ThemePath 'assets\media\generated'
$SiteModelPath = Join-Path $RepoRoot 'content\site-model.json'
$MediaManifestPath = Join-Path $RepoRoot 'assets\source\media\media-manifest.json'
$DockerfilePath = Join-Path $RepoRoot 'Dockerfile.wordpress'
$ThemeJsDir = Join-Path $ThemePath 'assets\js'

if ($ThemeSlug -cne $CanonicalThemeSlug) {
    throw "Unsupported QuickSilver theme slug '$ThemeSlug'. This repo owns one theme: $CanonicalThemeSlug."
}

function Assert-UnderRepo {
    param([string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $repoRootWithSeparator = $RepoFullPath.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if ($fullPath -ne $RepoFullPath -and -not $fullPath.StartsWith($repoRootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to read or write outside repo: $fullPath"
    }
}

function Assert-File {
    param([string]$Path)

    Assert-UnderRepo $Path
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Missing required file: $Path"
    }
}

function Assert-Command {
    param([string]$Name)

    if ($null -eq (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Missing required command '$Name'. Install it before running the local theme check."
    }
}

function Invoke-CheckedStep {
    param(
        [string]$Name,
        [scriptblock]$Script
    )

    Write-Host "==> $Name"
    & $Script
}

function Get-WordPressImageFromDockerfile {
    Assert-File $DockerfilePath
    $line = Get-Content -LiteralPath $DockerfilePath | Where-Object { $_ -match '^ARG WORDPRESS_IMAGE=(.+)$' } | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($line)) {
        throw "Dockerfile.wordpress must define ARG WORDPRESS_IMAGE for PHP lint."
    }

    if ($line -notmatch '^ARG WORDPRESS_IMAGE=(.+)$') {
        throw "Unable to parse WORDPRESS_IMAGE from Dockerfile.wordpress."
    }

    return $Matches[1]
}

Assert-UnderRepo $ThemePath
if (-not (Test-Path -LiteralPath $ThemePath -PathType Container)) {
    throw "Missing theme directory: $ThemePath"
}

Assert-File $SiteModelPath
Assert-File $MediaManifestPath
if (-not (Test-Path -LiteralPath $ThemeJsDir -PathType Container)) {
    throw "Missing theme JavaScript directory: $ThemeJsDir"
}

Invoke-CheckedStep 'Parse content/site-model.json' {
    Get-Content -LiteralPath $SiteModelPath -Raw | ConvertFrom-Json | Out-Null
}

Invoke-CheckedStep 'Parse assets/source/media/media-manifest.json' {
    Get-Content -LiteralPath $MediaManifestPath -Raw | ConvertFrom-Json | Out-Null
}

Invoke-CheckedStep 'Generate theme data' {
    & $PSScriptRoot\generate-theme-data.ps1 -ThemeSlug $ThemeSlug | Out-Host
}

Assert-File $GeneratedDataPath

Invoke-CheckedStep 'Check JavaScript syntax' {
    Assert-Command 'node'
    $scriptFiles = @(Get-ChildItem -LiteralPath $ThemeJsDir -Recurse -File -Filter '*.js' | Sort-Object FullName)
    if ($scriptFiles.Count -eq 0) {
        throw "No theme JavaScript files found under $ThemeJsDir."
    }

    foreach ($scriptFile in $scriptFiles) {
        & node --check $scriptFile.FullName
        if ($LASTEXITCODE -ne 0) {
            throw "node --check failed for $($scriptFile.FullName) with exit code $LASTEXITCODE."
        }
    }
}

if ([string]::IsNullOrWhiteSpace($WordPressImage)) {
    $WordPressImage = Get-WordPressImageFromDockerfile
}

Invoke-CheckedStep 'Lint theme PHP through the WordPress image' {
    Assert-Command 'docker'
    $mount = "${ThemeFullPath}:/theme:ro"
    & docker run --rm -v $mount $WordPressImage sh -lc "find /theme -name '*.php' -print0 | xargs -0 -n 1 php -l"
    if ($LASTEXITCODE -ne 0) {
        throw "PHP lint failed with exit code $LASTEXITCODE."
    }
}

Invoke-CheckedStep 'Package theme zip' {
    & $PSScriptRoot\package-theme.ps1 -ThemeSlug $ThemeSlug | Out-Host
}

Invoke-CheckedStep 'Check Git deploy hygiene' {
    Assert-Command 'git'
    Push-Location $RepoRoot
    try {
        & git diff --check HEAD --
        if ($LASTEXITCODE -ne 0) {
            throw "git diff --check failed with exit code $LASTEXITCODE."
        }

        $deployContextPaths = @(
            'Dockerfile.wordpress',
            'railway.toml',
            '.dockerignore',
            'docker',
            'theme/quicksilver-construction'
        )
        $untrackedDeployFiles = @(& git ls-files --others --exclude-standard -- $deployContextPaths)
        if ($untrackedDeployFiles.Count -gt 0) {
            throw "Untracked files would affect the WordPress image deploy. Track or remove them before deploying: $($untrackedDeployFiles -join ', ')"
        }

        $untrackedGeneratedFiles = @(& git ls-files --others --exclude-standard -- $GeneratedDataDir $GeneratedMediaDir)
        if ($untrackedGeneratedFiles.Count -gt 0) {
            throw "Generated theme outputs are untracked. Track or remove them before deploying: $($untrackedGeneratedFiles -join ', ')"
        }
    }
    finally {
        Pop-Location
    }
}

[pscustomobject]@{
    CheckedTheme = $ThemeSlug
    GeneratedData = $GeneratedDataPath
    WordPressImage = $WordPressImage
    Package = (Join-Path $RepoRoot "dist\$ThemeSlug.zip")
}
