# Conditional Access Policy Framework

A scope-based Conditional Access framework and baseline policy set for Microsoft Entra ID.

**Author:** Ivan Krpelnik | **Version:** 1.0 | **Last updated:** July 2026

The goal of this framework is a simple, scalable and operationally clear structure for creating, naming, reviewing and maintaining Conditional Access policies. Every policy is assigned to exactly one primary scope (Global, Admin, Internal, External, Agent, ServiceAccount). This keeps the policy list in the Entra admin center readable, sortable and filterable, and it makes gap analysis against this baseline straightforward.

## Repository contents

| Path | Content |
| --- | --- |
| `policies/` | The baseline policy set as Microsoft Graph JSON (create-payload format, UTF-8) |
| `scripts/Export-CAPolicies.ps1` | Refreshes `policies/` from a live tenant via Microsoft Graph |
| `scripts/Rename-CAPolicies.ps1` | Renames existing tenant policies to the current baseline names |
| `README.md` | This framework documentation |

## Using this repository with the CA Policy Analyzer

1. This repository must be **public** so the analyzer can fetch it anonymously.
2. In the analyzer, open **Templates**, paste the repository URL (`https://github.com/OWNER/REPO`) into the custom repo field and click **Load**.
3. JSON files are auto-detected in the `policies/` folder.
4. Because policy names carry the scope in the prefix (`CA-Admin-`, `CA-Internal-`, ...), the analyzer groups policies by persona automatically.

## Placeholders

The JSON files are sanitized for public sharing. Tenant-specific object IDs are replaced with tokens. Replace them before importing into a tenant:

| Token | Meaning | Replace with |
| --- | --- | --- |
| `REPLACE-WITH-BREAKGLASS-ACCOUNT-OBJECT-ID` | Emergency access exclusion, present in nearly every policy | Object ID of the break-glass account or, preferably, a break-glass exclusion group |
| `REPLACE-WITH-DEVICE-EXCLUSION-OBJECT-ID` | Exception from device compliance policies | Object ID of a documented device-exception user or group |
| `REPLACE-WITH-SERVICE-ACCOUNT-OBJECT-ID` | Target of the ServiceAccount scope policies | Object ID of the service account or service account group |
| `REPLACE-WITH-NAMED-LOCATION-ID` | Country-based named location used by CA-Global-120 | ID of the named location defining untrusted countries |

Entra role template IDs and built-in authentication strength IDs (for example `00000000-0000-0000-0000-000000000004` for Phishing-resistant MFA) are identical in every tenant and are intentionally kept.

## Baseline policy set

### Global (13 policies)

| Policy | Enforcement |
| --- | --- |
| CA-Global-010 \| Any Platform \| All Resources \| Block Legacy Authentication | Block |
| CA-Global-020 \| Any Platform \| Authentication Flows \| Block Device Code Flow | Block |
| CA-Global-030 \| Any Platform \| Authentication Flows \| Block Authentication Transfer | Block |
| CA-Global-040 \| Unknown Platforms \| All Resources \| Block Untrusted Platforms | Block |
| CA-Global-050 \| Any Platform \| All Resources \| Require MFA for Device Registration | Grant: mfa |
| CA-Global-060 \| iOS Android \| All Resources \| Require App Protection | Grant: compliantApplication |
| CA-Global-070 \| Any Platform \| All Resources \| Require MFA for Sign-in Risk | Grant: mfa; Session: sign-in frequency |
| CA-Global-080 \| Any Platform \| All Resources \| Require Password Change for User Risk | Grant: riskRemediation; Auth strength: Multifactor authentication; Session: sign-in frequency |
| CA-Global-090 \| Desktop Apps \| Office 365 \| Block Unmanaged Devices | Block |
| CA-Global-100 \| Browser \| Office 365 \| Restrict Unmanaged Sessions | Session: MDA session control |
| CA-Global-110 \| Browser \| Office 365 \| Monitor Unmanaged Sessions | Session: MDA session control, sign-in frequency |
| CA-Global-120 \| Any Platform \| All Resources \| Block Untrusted Countries | Block |
| CA-Global-130 \| Any Platform \| Microsoft Intune Enrollment \| Require Sign-in Frequency Every Time | Grant: mfa; Session: sign-in frequency |

### Admin (2 policies)

| Policy | Enforcement |
| --- | --- |
| CA-Admin-010 \| Any Platform \| All Resources \| Require Phishing-resistant MFA | Auth strength: Phishing-resistant MFA |
| CA-Admin-020 \| Browser \| Admin Portals \| Restrict Sessions | Session: sign-in frequency |

### Internal (3 policies)

| Policy | Enforcement |
| --- | --- |
| CA-Internal-010 \| Any Platform \| All Resources \| Require MFA | Grant: mfa; Session: sign-in frequency |
| CA-Internal-020 \| Windows \| Selected Resources \| Require Token Protection | Session: token protection |
| CA-Internal-030 \| Windows macOS \| All Resources \| Require Compliant Device | Grant: compliantDevice |

### External (3 policies)

| Policy | Enforcement |
| --- | --- |
| CA-External-010 \| Any Platform \| All Resources \| Require MFA | Grant: mfa |
| CA-External-020 \| Browser \| All Resources \| Restrict Sessions | Session: sign-in frequency |
| CA-External-030 \| Any Platform \| Admin Portals \| Block Access | Block |

### Agent (1 policies)

| Policy | Enforcement |
| --- | --- |
| CA-Agent-010 \| Any Platform \| All Resources \| Block High Risk | Block |

### ServiceAccount (1 policies)

| Policy | Enforcement |
| --- | --- |
| CA-ServiceAccount-010 \| Any Platform \| Named Locations \| Restrict Access | Block |

## Design principles

- **Simplicity.** Policy names must show what a policy does without opening it.
- **Scope-based structure.** Each policy belongs to one primary scope that defines its main target.
- **Human-readable naming.** Scope names are written out (`CA-Admin-010`), not abbreviated (`CA-ADM-010`).
- **No duplicate scope labels.** The scope lives in the prefix and is not repeated after the pipe separator.
- **Sequential numbering per scope.** Each scope has its own sequence starting at 010.
- **Scalability.** New policies and new scopes can be added without renumbering existing policies.
- **Operational clarity.** The naming convention supports filtering, sorting, review, troubleshooting and change management.

## Scope model

| Scope | Purpose |
| --- | --- |
| **Global** | Tenant-wide guardrail policies that apply broadly across multiple identity types |
| **Admin** | Privileged users, administrator roles and administrative portals |
| **Internal** | Internal workforce users |
| **External** | Guests, B2B users, partners, vendors and external collaborators |
| **Agent** | AI agents, agent identities and future autonomous identity scenarios |
| **ServiceAccount** | Non-human accounts, legacy service accounts and technical identities |

### Global

Tenant-wide guardrails that are not specific to one persona: block legacy authentication, block device code flow and authentication transfer, block unknown platforms and untrusted countries, risk-based controls (sign-in risk MFA, user risk password change), MFA for device registration and Intune enrollment.

### Admin

Privileged access is treated as a high-risk access path. Require MFA for all admin roles, prefer phishing-resistant authentication, restrict admin portal sessions, limit persistent role assignment via PIM, monitor privileged sign-ins, and exclude break-glass only where required.

### Internal

Employees and standard workforce users. Typical controls: MFA, compliant device requirements, token protection, app protection for mobile access, session controls for unmanaged browser access.

### External

Non-internal human users. External is preferred over Guests because it is broader: a guest account is one type of external identity. Typical controls: MFA, restricted browser sessions, blocked admin portal access, Terms of Use where required, limited resource access, guest lifecycle review.

### Agent

AI agents, Copilot agents, automation agents and agentic identities. Restrict access to required resources, block high-risk access, avoid broad permissions, monitor sign-ins, and keep agent identities separate from service accounts. This scope makes the model future-ready even if no agent identities exist yet.

### ServiceAccount

Legacy service accounts and technical identities that cannot use standard MFA. Block interactive sign-in where possible, restrict access to named locations and required applications only, avoid MFA exclusions without compensating controls, and review ownership regularly. Service accounts must never be hidden inside Internal or Global exception logic without documentation.

## Naming convention

```
CA-[Scope]-[Sequence] | [Platform] | [Resource] | [Control]
```

Example: `CA-Internal-010 | Any Platform | All Resources | Require MFA`

| Component | Description | Examples |
| --- | --- | --- |
| `CA` | Identifies the object as a Conditional Access policy | CA |
| `[Scope]` | Primary policy scope | Global, Admin, Internal, External, Agent, ServiceAccount |
| `[Sequence]` | Sequential number within the scope, always three digits | 010, 020, 110 |
| `[Platform]` | Targeted platform condition | Any Platform, Windows, iOS Android, Unknown Platforms |
| `[Resource]` | Targeted cloud app, action or resource | All Resources, Office 365, Admin Portals, Authentication Flows |
| `[Control]` | Main access or session control | Require MFA, Block Access, Require Compliant Device |

### Numbering rules

- Each scope has its own independent sequence: 010, 020, 030, ...
- Three digits keep sorting clean past 100 (`CA-Global-090`, `CA-Global-100`, never `CA-Global-90`).
- Numbers stay stable. Gaps from retired policies are not backfilled and production policies are not renumbered outside a controlled cleanup project.

### Platform naming standard

Use: `Any Platform`, `Windows`, `macOS`, `Windows macOS`, `iOS Android`, `Linux`, `Unknown Platforms`.
Avoid: `All Platforms`, `Any Device`, `All OS`, `Win`, `Android/iOS`.

### Resource naming standard

Use: `All Resources`, `Office 365`, `Admin Portals`, `Authentication Flows`, `Named Locations`, `Selected Resources`, or a specific app name.

### Control naming standard

Use clear verbs: `Block`, `Require`, `Restrict`, `Route`, `Grant`.
Examples: `Block Legacy Authentication`, `Require Phishing-resistant MFA`, `Restrict Sessions`, `Route Sessions to Defender for Cloud Apps`.
Avoid vague labels such as `Secure Access`, `Protect Users`, `Baseline Policy`, `Default Policy`.

## Scope selection rules

- Use **Global** when the policy is a tenant-wide guardrail applying to multiple identity groups.
- Use **Admin** when the policy targets admin roles, privileged users or admin portals.
- Use **Internal** when the policy targets employees or corporate users.
- Use **External** when the policy targets guests, B2B users, vendors or partners.
- Use **Agent** when the policy targets AI agents, automation agents or future autonomous identities.
- Use **ServiceAccount** when the policy targets legacy service accounts or technical non-human identities.

## Policy description standard

The policy name stays short and operational; the description carries the detail. Every policy description should contain:

| Field | Content |
| --- | --- |
| Purpose | Why the policy exists |
| Target | Users, groups, roles or identities targeted |
| Exclusions | Excluded accounts, groups, applications or conditions |
| Conditions | Platforms, locations, client apps, risk levels, device states |
| Controls | Grant, session or block controls |
| Operational Notes | Rollout state, dependencies, known exceptions, review notes |
| Owner | Technical or process owner |
| Last Review | Date of the last review (YYYY-MM-DD) |

## Rollout model

Policies are rolled out in controlled phases:

```
Draft -> Report-only -> Pilot -> Production -> Review -> Retire
```

1. **Draft**: designed and documented, not active.
2. **Report-only**: enabled in report-only mode to evaluate impact without enforcement.
3. **Pilot**: enforced for a controlled pilot group.
4. **Production**: enforced for the full intended scope.
5. **Review**: reviewed periodically for relevance, exceptions and impact.
6. **Retire**: disabled and removed when no longer required, with the replacement documented.

Report-only is mandatory before broad enforcement whenever a policy affects all users, all resources, device compliance or risk-based access.

## Exclusion management

Exclusions are minimized and documented. Every exclusion needs a business reason, technical reason, owner, approval, review date, compensating control and, where possible, a removal plan.

Common legitimate exclusions: break-glass accounts, specific service accounts, specific technical applications, known unsupported legacy scenarios, temporary migration groups.

Avoid broad exclusions such as all IT users, all admins, all trusted locations or large permanent exception groups.

## Break-glass accounts

- Cloud-only accounts, excluded from every policy that could lock out emergency access.
- Strong authentication where operationally feasible.
- Aggressive sign-in monitoring with an alert on every successful sign-in.
- No use for normal administration, regular review.

## Operations

### Filtering

The prefix makes the policy list filterable: filter by `CA-Global` for guardrails, `CA-Admin` for privileged access, `CA-Internal` for workforce, `CA-External` for guests and partners, `CA-Agent` for agent identities, `CA-ServiceAccount` for technical accounts. This is the main operational benefit of the naming convention.

### Change management

Every production change documents: policy name and purpose, target, exclusions, resources, conditions, grant and session controls, expected impact, rollback plan, approver, implementation date and validation result.

### Review process

Review items: policy still required, target still correct, exclusions still valid (including break-glass and service accounts), report-only findings, sign-in logs, risk detections, user impact, description updated, owner confirmed.

Review frequency: high-impact policies quarterly, standard baseline every 6 months, temporary policies monthly until removed, emergency policies after every use.

### Adding a new policy

1. Identify the primary scope.
2. Take the next free sequence number in that scope.
3. Apply the naming template and write a complete description.
4. Start in report-only, review sign-in logs, pilot if needed, then move to production.
5. Document exceptions and owner.

### Adding a new scope

The model is modular. New scopes (for example `CA-Device`, `CA-Developer`, `CA-Executive`, `CA-PrivilegedWorkstation`) can be added later, but only when they genuinely improve operational clarity and are not already covered by an existing scope.

### Retiring or renaming

Keep existing numbers stable, disable obsolete policies first, document the replacement in the description, remove after validation, avoid frequent renaming in production.

## Deploying the baseline to a tenant

1. Replace all `REPLACE-WITH-*` tokens (see Placeholders above). Use dedicated exclusion groups per policy rather than individual users where possible.
2. Create the required named location for CA-Global-120 before import.
3. Import the JSON payloads via Microsoft Graph (`POST /identity/conditionalAccess/policies`) or a deployment tool of your choice.
4. Set every imported policy to **report-only** first, regardless of the `state` value in this repository, and follow the rollout model above.
5. Confirm break-glass exclusions before enabling any blocking policy.

## Disclaimer

This baseline is a starting point, not a turnkey configuration. Every control must be validated against the specific tenant, its licensing and its operational requirements before enforcement. Use at your own risk.
