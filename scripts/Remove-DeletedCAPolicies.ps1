<#
.SYNOPSIS
    Permanently deletes ALL soft-deleted Conditional Access policies (empties the recycle bin).

.DESCRIPTION
    Deleted Conditional Access policies stay restorable for 30 days. This script
    purges them early. Permanent deletion is irreversible: purged policies cannot
    be restored through any interface. The mandatory -TenantId parameter and the
    post-connect guard make sure the purge can only ever run against the tenant
    you named.

.EXAMPLE
    .\Remove-DeletedCAPolicies.ps1 -TenantId "00000000-0000-0000-0000-000000000000" -WhatIf
    .\Remove-DeletedCAPolicies.ps1 -TenantId "00000000-0000-0000-0000-000000000000"

.NOTES
    Requires the Microsoft.Graph.Authentication module.
    Delegated scope: Policy.ReadWrite.ConditionalAccess
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [string]$TenantId
)

Connect-MgGraph -TenantId $TenantId -Scopes 'Policy.ReadWrite.ConditionalAccess' -NoWelcome

$ctx = Get-MgContext
if ($ctx.TenantId -ne $TenantId) {
    throw "Connected to tenant $($ctx.TenantId), expected $TenantId. Aborting."
}
Write-Host "Confirmed tenant $($ctx.TenantId) as $($ctx.Account)"

$deletedUri = 'https://graph.microsoft.com/beta/identity/conditionalAccess/deletedItems/policies'
$deleted = Invoke-MgGraphRequest -Method GET -Uri $deletedUri -OutputType PSObject
Write-Host "Soft-deleted Conditional Access policies found: $($deleted.value.Count)"

$purged = 0
foreach ($p in $deleted.value) {
    if ($PSCmdlet.ShouldProcess($p.displayName, 'PERMANENTLY delete Conditional Access policy')) {
        Invoke-MgGraphRequest -Method DELETE -Uri "$deletedUri/$($p.id)"
        Write-Host "Permanently deleted: $($p.displayName)"
        $purged++
    }
}

$remaining = (Invoke-MgGraphRequest -Method GET -Uri $deletedUri -OutputType PSObject).value.Count
Write-Host "Done. Purged $purged. Soft-deleted policies remaining: $remaining"
