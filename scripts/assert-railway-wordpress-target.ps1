[CmdletBinding()]
param(
    [string]$RailwayDir,

    [string]$ProjectId = '9680e4f9-863d-4987-92f5-bcb2d643331a',

    [string]$Environment = 'production',

    [string]$Service = 'WordPress'
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($RailwayDir)) {
    $RailwayDir = Join-Path (Split-Path -Parent $RepoRoot) 'quicksilver-wp-railway'
}

if (-not (Test-Path -LiteralPath $RailwayDir -PathType Container)) {
    throw "Railway link directory not found: $RailwayDir"
}

Push-Location $RailwayDir
try {
    $status = railway status --json | ConvertFrom-Json
}
finally {
    Pop-Location
}

if ($status.id -ne $ProjectId) {
    throw "Railway project mismatch. Expected $ProjectId but found $($status.id)."
}

$environmentNode = @($status.environments.edges.node | Where-Object { $_.name -eq $Environment })
if ($environmentNode.Count -ne 1) {
    throw "Expected exactly one Railway environment named $Environment."
}

$serviceNode = @($environmentNode[0].serviceInstances.edges.node | Where-Object { $_.serviceName -eq $Service })
if ($serviceNode.Count -ne 1) {
    throw "Expected exactly one Railway service named $Service."
}

$volumeMounts = @($serviceNode[0].latestDeployment.meta.volumeMounts)
if ($volumeMounts -notcontains '/var/www/html') {
    throw "WordPress service is missing expected /var/www/html volume mount."
}

if ($serviceNode[0].latestDeployment.status -ne 'SUCCESS') {
    throw "Latest WordPress deployment is not SUCCESS. Current status: $($serviceNode[0].latestDeployment.status)"
}

[pscustomobject]@{
    Validated = $true
    ProjectId = $status.id
    Environment = $Environment
    Service = $Service
    ServiceId = $serviceNode[0].serviceId
    DeploymentId = $serviceNode[0].latestDeployment.id
    DeploymentStatus = $serviceNode[0].latestDeployment.status
    VolumeMount = '/var/www/html'
    RailwayDir = $RailwayDir
}
