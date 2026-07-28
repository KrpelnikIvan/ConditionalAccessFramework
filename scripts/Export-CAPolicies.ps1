<#
.SYNOPSIS
    Exports Conditional Access policies from Entra ID into clean Graph JSON files for this repository.

.DESCRIPTION
    - Reads all CA policies via Microsoft Graph (beta endpoint)
    - Keeps only displayName, state, conditions, grantControls, sessionControls
    - Reduces authenticationStrength to id and displayName (built-in strength IDs are tenant independent)
    - Replaces tenant specific object IDs with placeholder tokens (see -TokenMap)
    - Writes UTF-8 (no BOM) JSON files into the policies folder, one file per policy

.EXAMPLE
    .\Export-CAPolicies.ps1 -TokenMap @{
        'afec80a2-6a8b-4762-8bff-33d0b870d49c' = 'REPLACE-WITH-BREAKGLASS-ACCOUNT-OBJECT-ID'
        '1a81d570-416b-4a68-b443-89cf8b2c51ac' = 'REPLACE-WITH-NAMED-LOCATION-ID'
    }

.NOTES
    Requires the Microsoft.Graph.Authentication module. Delegated scope: Policy.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputFolder = (Join-Path $PSScriptRoot '..\policies'),
    [hashtable]$TokenMap = @{}
)

Connect-MgGraph -Scopes 'Policy.Read.All' -NoWelcome

$uri = 'https://graph.microsoft.com/beta/identity/conditionalAccess/policies'
$policies = @()
do {
    $response = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject
    $policies += $response.value
    $uri = $response.'@odata.nextLink'
} while ($uri)

if (-not (Test-Path $OutputFolder)) { New-Item -ItemType Directory -Path $OutputFolder | Out-Null }

foreach ($p in $policies) {
    $payload = [ordered]@{
        displayName     = ($p.displayName -replace '\s+', ' ').Trim()
        state           = $p.state
        conditions      = $p.conditions
        grantControls   = $p.grantControls
        sessionControls = $p.sessionControls
    }

    if ($payload.grantControls -and $payload.grantControls.authenticationStrength) {
        $payload.grantControls.authenticationStrength = [ordered]@{
            id          = $payload.grantControls.authenticationStrength.id
            displayName = $payload.grantControls.authenticationStrength.displayName
        }
    }

    $json = $payload | ConvertTo-Json -Depth 20
    foreach ($id in $TokenMap.Keys) {
        $json = $json -replace [regex]::Escape($id), $TokenMap[$id]
    }

    $fileName = ($payload.displayName -replace ' \| ', ' - ') -replace '[\\/:*?"<>|]', ' '
    $fileName = (($fileName -replace '\s+', ' ').Trim()) + '.json'
    [System.IO.File]::WriteAllText((Join-Path $OutputFolder $fileName), $json, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Exported: $fileName"
}

Write-Host "Done. $($policies.Count) policies written to $OutputFolder"
