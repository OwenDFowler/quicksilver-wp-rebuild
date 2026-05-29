[CmdletBinding()]
param(
    [string]$RailwayDir,

    [string]$ProjectId = '9680e4f9-863d-4987-92f5-bcb2d643331a',

    [string]$Environment = 'production',

    [string]$Service = 'WordPress',

    [string]$Message = 'Deploy QuickSilver WordPress control image with WP-CLI',

    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($RailwayDir)) {
    $RailwayDir = Join-Path (Split-Path -Parent $RepoRoot) 'quicksilver-wp-railway'
}

if (-not (Test-Path -LiteralPath $RailwayDir -PathType Container)) {
    throw "Railway link directory not found: $RailwayDir"
}

$requiredRepoFiles = @(
    'Dockerfile.wordpress',
    'railway.toml',
    '.dockerignore',
    'docker\wordpress-start.sh',
    'scripts\assert-railway-wordpress-target.ps1',
    'scripts\check-theme-local.ps1',
    'scripts\generate-theme-data.ps1',
    'theme\quicksilver-construction\style.css',
    'theme\quicksilver-construction\index.php'
)

foreach ($relativePath in $requiredRepoFiles) {
    $path = Join-Path $RepoRoot $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing required deploy file: $path"
    }
}

$target = & $PSScriptRoot\assert-railway-wordpress-target.ps1 `
    -RailwayDir $RailwayDir `
    -ProjectId $ProjectId `
    -Environment $Environment `
    -Service $Service

if ($ValidateOnly) {
    [pscustomobject]@{
        Validated = $true
        ProjectId = $target.ProjectId
        Environment = $Environment
        Service = $Service
        VolumeMount = '/var/www/html'
        DeployFiles = $requiredRepoFiles
    }
    return
}

& $PSScriptRoot\check-theme-local.ps1 | Out-Host

Push-Location $RepoRoot
try {
    & railway up --project $ProjectId --environment $Environment --service $Service --message $Message --ci
    if ($LASTEXITCODE -ne 0) {
        throw "Railway deploy failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

& $PSScriptRoot\assert-railway-wordpress-target.ps1 `
    -RailwayDir $RailwayDir `
    -ProjectId $ProjectId `
    -Environment $Environment `
    -Service $Service
