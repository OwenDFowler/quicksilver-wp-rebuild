[CmdletBinding()]
param(
    [string]$EnvFile
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($EnvFile)) {
    $EnvFile = Join-Path $RepoRoot '.env.local'
}

if (-not (Test-Path -LiteralPath $EnvFile)) {
    throw "Missing local env file: $EnvFile. Run scripts\init-local-env.ps1 first."
}

$values = @{}
Get-Content -LiteralPath $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if ($line.Length -eq 0 -or $line.StartsWith('#')) {
        return
    }

    $parts = $line.Split('=', 2)
    if ($parts.Count -ne 2) {
        throw "Invalid env line: $line"
    }

    $values[$parts[0]] = $parts[1]
}

$baseUrl = $values['WORDPRESS_BASE_URL']
$username = $values['WORDPRESS_USERNAME']
$appPassword = $values['WORDPRESS_APPLICATION_PASSWORD']

if ([string]::IsNullOrWhiteSpace($baseUrl) -or [string]::IsNullOrWhiteSpace($username) -or [string]::IsNullOrWhiteSpace($appPassword)) {
    throw "WORDPRESS_BASE_URL, WORDPRESS_USERNAME, and WORDPRESS_APPLICATION_PASSWORD must all be set in .env.local."
}

$baseUrl = $baseUrl.TrimEnd('/')
$normalizedPassword = ($appPassword -replace '\s+', '')
$tokenBytes = [System.Text.Encoding]::UTF8.GetBytes("${username}:${normalizedPassword}")
$headers = @{
    Authorization = 'Basic ' + [Convert]::ToBase64String($tokenBytes)
}

$response = Invoke-RestMethod -Uri "$baseUrl/wp-json/wp/v2/users/me?context=edit" -Headers $headers -Method Get

[pscustomobject]@{
    Authenticated = $true
    Id = $response.id
    Username = $response.username
    Name = $response.name
    Roles = ($response.roles -join ',')
}
