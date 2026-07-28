<#
.SYNOPSIS
    Deletes ALL active Conditional Access policies in the specified tenant.

.DESCRIPTION
    Intended to reset a tenant before a clean baseline import, because
    IntuneManagement's "Always import" creates duplicates on repeated runs.
    The mandatory -TenantId parameter and the post-connect guard make sure
    the delete can only ever run against the tenant you named.

    Deleted policies move to the Conditional Access recycle bin and can be
    restored for 30 days. Use Remove-DeletedCAPolicies.ps1 to purge them.

.EXAMPLE
    .\Remove-CAPolicies.ps1 -TenantId "00000000-0000-0000-0000-000000000000" -WhatIf
    .\Remove-CAPolicies.ps1 -TenantId "00000000-0000-0000-0000-000000000000"

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

$policies = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/beta/identity/conditionalAccess/policies' -OutputType PSObject
Write-Host "Active Conditional Access policies found: $($policies.value.Count)"

$deleted = 0
foreach ($p in $policies.value) {
    if ($PSCmdlet.ShouldProcess($p.displayName, 'Delete Conditional Access policy')) {
        Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/beta/identity/conditionalAccess/policies/$($p.id)"
        Write-Host "Deleted: $($p.displayName)"
        $deleted++
    }
}

$remaining = (Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/beta/identity/conditionalAccess/policies' -OutputType PSObject).value.Count
Write-Host "Done. Deleted $deleted. Active policies remaining: $remaining"
