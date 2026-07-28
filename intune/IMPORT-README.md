# Importing this baseline with IntuneManagement

This folder contains the baseline in the native export format of the IntuneManagement tool by Micke-K: `ConditionalAccess/*.json` (24 policies, full `@odata` annotations) plus `MigrationTable.json`. Use this folder for IntuneManagement imports. The `policies/` folder in the repository root holds the same baseline as clean Graph create-payloads for the CA Policy Analyzer and direct Graph deployment; the two folders are semantically identical.

## How the references work

**Groups (handled automatically).** The migration table maps three friendly names to the placeholder IDs inside the policy files. With "Replace Dependency IDs" enabled, the tool resolves each name against the target tenant on import: if the group exists it is matched by name, if not it is created as an empty cloud security group. All group references sit in `excludeGroups` (and `includeGroups` for the service account policy). Do not move them into the user arrays: group IDs in `excludeUsers` still evaluate, but the portal renders them as deleted users and shows a warning banner on every policy.

| Friendly name | Purpose |
| --- | --- |
| CA-BreakGlass-Exclusions | Break-glass account(s), excluded from every policy |
| CA-DeviceCompliance-Exclusions | Documented exceptions from the device compliance policies |
| CA-ServiceAccounts | Service account(s), target of CA-ServiceAccount-010 and pre-excluded from MFA and compliance policies |

**Named locations (manual, per tenant).** The tool does not create named locations and the migration table cannot remap them. The two location IDs inside `CA-Global-120` and `CA-ServiceAccount-010` are therefore hardcoded and tenant-specific. Before importing into a new tenant: create both locations, look up their IDs, and replace the IDs in those two files.

```powershell
Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/identity/conditionalAccess/namedLocations" -OutputType PSObject |
  Select-Object -ExpandProperty value | Select-Object displayName, id
```

Required locations: `Untrusted Countries` (Countries type, the blocklist for CA-Global-120) and `Service Account Trusted IPs` (IP ranges type, the egress IPs excluded by CA-ServiceAccount-010). If a referenced location ID does not exist, Graph rejects the policy with 400 Bad Request.

## Import procedure

1. Create the two named locations and patch their IDs into the two files (see above).
2. Start from an empty state. "Always import" creates a new policy on every run, so repeated imports produce duplicates. Clear existing baseline policies first with `scripts/Remove-CAPolicies.ps1`.
3. In IntuneManagement: Conditional Access, Import. Point at the folder containing both `ConditionalAccess` and `MigrationTable.json` (keep them together).
4. Settings: **Replace Dependency IDs: checked** (required, this is the group resolution). Assign Scope (Tags): unchecked. Import Assignments: unchecked. Conditional Access State: **Off** (report-only). Import Type: Always import is safe only against an empty tenant.
5. Import. Expect 24 successes.

## After import

1. Verify a sample policy shows excluded identities as `0 users, 3 groups` (or 1 group on policies that only exclude break-glass). A "users deleted from the directory" banner means group IDs landed in the wrong field; do not proceed, re-check the files.
2. Populate the groups, break-glass first: two break-glass accounts recommended in `CA-BreakGlass-Exclusions`, the service account(s) in `CA-ServiceAccounts`, documented exceptions in `CA-DeviceCompliance-Exclusions`. The tool creates these groups empty; an empty break-glass group protects nothing.
3. Populate the `Untrusted Countries` list with real countries.
4. Follow the rollout model: report-only, pilot, production. Complete the "Required tenant configuration before deployment" checklist in the main README before enforcing anything.

## Known tool limitations

- Named locations are neither created nor remapped; their IDs must be maintained per tenant.
- "Always import" duplicates on re-runs; there is no update-in-place for Conditional Access.
- Groups are created empty; membership is always a manual post-import step.
- The Bulk menu has no delete for Conditional Access objects; use `scripts/Remove-CAPolicies.ps1` for cleanup and `scripts/Remove-DeletedCAPolicies.ps1` to purge the 30-day recycle bin.
