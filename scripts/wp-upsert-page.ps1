[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$File,

    [switch]$Publish
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $File)) {
    throw "Page file not found: $File"
}

$page = Get-Content -LiteralPath $File -Raw | ConvertFrom-Json

if ([string]::IsNullOrWhiteSpace($page.title) -or [string]::IsNullOrWhiteSpace($page.slug) -or [string]::IsNullOrWhiteSpace($page.content)) {
    throw "Page JSON must include title, slug, and content."
}

$status = if ($Publish) { 'publish' } elseif ([string]::IsNullOrWhiteSpace($page.status)) { 'draft' } else { $page.status }

if ($status -ne 'draft' -and $status -ne 'publish') {
    throw "Only draft and publish statuses are supported by this script."
}

$encodedSlug = [uri]::EscapeDataString($page.slug)
$existing = & $PSScriptRoot\wp-rest.ps1 -Path "wp/v2/pages?slug=$encodedSlug&context=edit"

$body = @{
    title = $page.title
    slug = $page.slug
    content = $page.content
    status = $status
} | ConvertTo-Json -Depth 10

if (@($existing).Count -gt 0) {
    $target = @($existing)[0]
    $result = & $PSScriptRoot\wp-rest.ps1 -Path "wp/v2/pages/$($target.id)" -Method POST -BodyJson $body
    $action = 'updated'
} else {
    $result = & $PSScriptRoot\wp-rest.ps1 -Path 'wp/v2/pages' -Method POST -BodyJson $body
    $action = 'created'
}

[pscustomobject]@{
    Action = $action
    Id = $result.id
    Slug = $result.slug
    Status = $result.status
    Link = $result.link
}
