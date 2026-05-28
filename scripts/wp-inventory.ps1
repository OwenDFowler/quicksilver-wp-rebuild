[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$me = & $PSScriptRoot\wp-rest.ps1 -Path 'wp/v2/users/me?context=edit'
$types = & $PSScriptRoot\wp-rest.ps1 -Path 'wp/v2/types'
$pages = & $PSScriptRoot\wp-rest.ps1 -Path 'wp/v2/pages?per_page=100&status=any&context=edit&_fields=id,slug,status,title,link,modified'
$posts = & $PSScriptRoot\wp-rest.ps1 -Path 'wp/v2/posts?per_page=100&status=any&context=edit&_fields=id,slug,status,title,link,modified'
$media = & $PSScriptRoot\wp-rest.ps1 -Path 'wp/v2/media?per_page=20&_fields=id,slug,media_type,mime_type,source_url,modified'

[pscustomobject]@{
    User = [pscustomobject]@{
        Id = $me.id
        Username = $me.username
        Roles = $me.roles
    }
    Types = ($types.PSObject.Properties.Name | Sort-Object)
    PageCount = @($pages).Count
    PostCount = @($posts).Count
    RecentMediaCount = @($media).Count
    Pages = $pages
    Posts = $posts
    RecentMedia = $media
}
