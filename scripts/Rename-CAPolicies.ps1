<#
.SYNOPSIS
    Renames existing Conditional Access policies in the tenant to match the current baseline names.

.DESCRIPTION
    Applies the July 2026 renumbering of this framework:
    - Global scope becomes strictly sequential 010 to 130 (removes the duplicate 030 and 040 numbers)
    - Admin scope restarts at 010
    - Aligns names with the platform and resource naming standards
    Matching is done on the whitespace-normalized display name, so trailing or double
    spaces in existing policy names do not prevent a match.

    Run with -WhatIf first to preview the changes.

.EXAMPLE
    .\Rename-CAPolicies.ps1 -WhatIf
    .\Rename-CAPolicies.ps1

.NOTES
    Requires the Microsoft.Graph.Authentication module.
    Delegated scope: Policy.ReadWrite.ConditionalAccess
#>
[CmdletBinding(SupportsShouldProcess)]
param()

$renameMap = @{
    'CA-Global-030 | Unknown Platforms | All Resources | Block Untrusted Platforms'                       = 'CA-Global-040 | Unknown Platforms | All Resources | Block Untrusted Platforms'
    'CA-Global-040 | Any Platform | All Resources | Require MFA for Device Registration'                  = 'CA-Global-050 | Any Platform | All Resources | Require MFA for Device Registration'
    'CA-Global-040 | iOS Android | All Resources | Require App Protection'                                = 'CA-Global-060 | iOS Android | All Resources | Require App Protection'
    'CA-Global-050 | Any Platform | All Resources | ID Protection | Require MFA for Sign-in Risk'         = 'CA-Global-070 | Any Platform | All Resources | Require MFA for Sign-in Risk'
    'CA-Global-060 | Any Platform | All Resources | ID Protection | Require Password Change for User Risk' = 'CA-Global-080 | Any Platform | All Resources | Require Password Change for User Risk'
    'CA-Global-070 | Desktop Apps | Office 365 | Block Unmanaged Devices'                                 = 'CA-Global-090 | Desktop Apps | Office 365 | Block Unmanaged Devices'
    'CA-Global-090 | Browser | Office 365 | Restrict Unmanaged Sessions'                                  = 'CA-Global-100 | Browser | Office 365 | Restrict Unmanaged Sessions'
    'CA-Global-100 | Browser | Office 365 | Monitor Unmanaged Sessions'                                   = 'CA-Global-110 | Browser | Office 365 | Monitor Unmanaged Sessions'
    'CA-Global-110 | Any Platform | All Resources | Block Untrusted Countries'                            = 'CA-Global-120 | Any Platform | All Resources | Block Untrusted Countries'
    'CA-Global-120 | Any Platform | Microsoft Intune Enrollment | Sign-in frequency Every Time'           = 'CA-Global-130 | Any Platform | Microsoft Intune Enrollment | Require Sign-in Frequency Every Time'
    'CA-Admin-020 | Any Platform | All Resources | Require Phishing-resistant MFA'                        = 'CA-Admin-010 | Any Platform | All Resources | Require Phishing-resistant MFA'
    'CA-Admin-030 | Browser | Admin Portals | Restrict Sessions'                                          = 'CA-Admin-020 | Browser | All Resources | Restrict Sessions'
    'CA-Internal-020 | Windows | Special Resources | Require Token Protection'                            = 'CA-Internal-020 | Windows | Selected Resources | Require Token Protection'
    'CA-Internal-030 | Windows/MacOS | All Resources | Require Compliant Device'                          = 'CA-Internal-030 | Windows macOS | All Resources | Require Compliant Device'
}

Connect-MgGraph -Scopes 'Policy.ReadWrite.ConditionalAccess' -NoWelcome

$uri = 'https://graph.microsoft.com/beta/identity/conditionalAccess/policies'
$policies = @()
do {
    $response = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject
    $policies += $response.value
    $uri = $response.'@odata.nextLink'
} while ($uri)

# Renaming order matters: process descending so CA-Global-100 is renamed to 110
# before another policy takes the 100 slot. Duplicate names are technically
# allowed in Entra, this just keeps the intermediate state clean.
$targets = $policies | Where-Object {
    $renameMap.ContainsKey((($_.displayName -replace '\s+', ' ').Trim()))
} | Sort-Object displayName -Descending

$renamed = 0
foreach ($p in $targets) {
    $normalized = ($p.displayName -replace '\s+', ' ').Trim()
    $newName = $renameMap[$normalized]
    if ($PSCmdlet.ShouldProcess($normalized, "Rename to '$newName'")) {
        $body = @{ displayName = $newName } | ConvertTo-Json
        Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/beta/identity/conditionalAccess/policies/$($p.id)" -Body $body -ContentType 'application/json'
        Write-Host "Renamed: $normalized -> $newName"
        $renamed++
    }
}

Write-Host "Done. $renamed of $($targets.Count) matching policies renamed."
