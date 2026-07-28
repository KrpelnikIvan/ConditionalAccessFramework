# Conditional Access Policy Framework

A scope-based Conditional Access framework and baseline policy set for Microsoft Entra ID.

**Author:** Ivan Krpelnik | **Version:** 1.1 | **Last updated:** July 2026

The goal of this framework is a simple, scalable and operationally clear structure for creating, naming, reviewing and maintaining Conditional Access policies. Every policy is assigned to exactly one primary scope (Global, Admin, Internal, External, Agent, ServiceAccount). This keeps the policy list in the Entra admin center readable, sortable and filterable, and it makes gap analysis against this baseline straightforward.

## Repository contents

| Path | Content |
| --- | --- |
| `policies/` | The baseline policy set as Microsoft Graph JSON (create-payload format, UTF-8) |
| `intune/` | The same baseline in IntuneManagement native format, with `MigrationTable.json` and an import guide |
| `scripts/` | Graph helpers: export, guarded delete-all, purge soft-deleted, tenant rename |
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
| `REPLACE-WITH-BREAKGLASS-GROUP-ID` | Emergency access exclusion group, excluded from every policy | Object ID of the break-glass security group |
| `REPLACE-WITH-DEVICE-EXCLUSION-GROUP-ID` | Exception group for the device compliance policies | Object ID of the device-exception security group |
| `REPLACE-WITH-SERVICE-ACCOUNT-GROUP-ID` | Target of the ServiceAccount scope and pre-excluded from the interactive policies it cannot satisfy | Object ID of the service account security group |
| `REPLACE-WITH-UNTRUSTED-COUNTRIES-LOCATION-ID` | Country named location referenced by CA-Global-120 | ID of the `Untrusted Countries` named location (country blocklist). Create it before import |
| `REPLACE-WITH-SERVICE-ACCOUNT-LOCATION-ID` | IP named location excluded by CA-ServiceAccount-010 | ID of the named location containing the service account egress IPs. Create it before import |

Entra role template IDs and built-in authentication strength IDs (for example `00000000-0000-0000-0000-000000000004` for Phishing-resistant MFA) are identical in every tenant and are intentionally kept. Exclusions are group-based by design: three security groups carry the break-glass, device-exception and service-account memberships, and every group reference sits in `excludeGroups` or `includeGroups`. The `intune/` package resolves these three groups automatically through its migration table; its two named-location IDs are tenant-specific and must be replaced per tenant (see `intune/IMPORT-README.md`).

## Required tenant configuration before deployment

The policies reference objects and platform features that must already exist in the target tenant. Complete this checklist before importing. Missing items either break the import (referenced named locations) or lock accounts out once policies are enforced.

| # | Prerequisite | Required by |
| --- | --- | --- |
| 1 | Break-glass account: cloud-only, excluded from every policy, monitored with an alert on every successful sign-in | All policies |
| 2 | Named location `Untrusted Countries` containing the country list to block. The Graph import fails if the referenced location ID does not exist | CA-Global-120 |
| 3 | An IP-based named location containing the egress IPs the service accounts sign in from. The policy excludes this specific location, so it does not need to be marked as Trusted. The import fails if the referenced location ID does not exist | CA-ServiceAccount-010 |
| 4 | Intune device compliance policies assigned for Windows and macOS | CA-Internal-030, CA-Global-090 |
| 5 | Intune app protection policies for iOS and Android (Outlook, Office, Edge) | CA-Global-060 |
| 6 | Microsoft Defender for Cloud Apps: Office 365 onboarded to Conditional Access App Control and session policies created. `mcasConfigured` routes traffic but enforces nothing until session policies exist | CA-Global-100, CA-Global-110 |
| 7 | Phishing-resistant methods (passkey, FIDO2 security key, Windows Hello for Business) registered for every administrator before enforcement. Onboard new administrators with a Temporary Access Pass | CA-Admin-010 |
| 8 | Licensing: Entra ID P1 for the baseline, P2 for the risk-based policies | CA-Global-070, CA-Global-080, CA-Global-140, CA-Global-150 |
| 9 | Service account exclusions are pre-wired: the service account token is already excluded from the interactive user policies it cannot satisfy (MFA, compliant device). Replace the token with the service account group and document the compensating controls | CA-Internal-010, CA-Internal-030, CA-Global-090 |
| 10 | Token protection: verify client support for the scoped services (Windows desktop clients only) and start in report-only | CA-Internal-020 |

Deploy in the order of the rollout model: report-only, pilot, production.

## Baseline policy set

### Global (15 policies)

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
| CA-Global-140 \| Any Platform \| All Resources \| Block High Sign-in Risk | Block |
| CA-Global-150 \| Any Platform \| All Resources \| Block High User Risk | Block |

### Admin (2 policies)

| Policy | Enforcement |
| --- | --- |
| CA-Admin-010 \| Any Platform \| All Resources \| Require Phishing-resistant MFA | Auth strength: Phishing-resistant MFA |
| CA-Admin-020 \| Browser \| All Resources \| Restrict Sessions | Session: sign-in frequency |

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

### ServiceAccount (1 policies)

| Policy | Enforcement |
| --- | --- |
| CA-ServiceAccount-010 \| Any Platform \| Named Locations \| Restrict Access | Block |

## Policy design notes

These decisions are deliberate. Understand them before changing individual policies.

**Managed device definition.** CA-Global-090, CA-Global-100 and CA-Global-110 share one definition of a managed device: compliant, Microsoft Entra joined, or Microsoft Entra hybrid joined (`device.isCompliant -eq True -or device.trustType -eq "AzureAD" -or device.trustType -eq "ServerAD"`). Everything else is treated as unmanaged.

**Admin MFA layering.** Administrators are covered twice by design: CA-Internal-010 provides baseline MFA as a fallback layer, CA-Admin-010 enforces phishing-resistant MFA on top. Do not exclude admin roles from CA-Internal-010; the stricter policy wins while both are enabled, and the base policy protects admins if the stricter one is ever disabled or misscoped.

**Risk layering.** Grant policies remediate, block policies stop. CA-Global-070 requires MFA for medium and high sign-in risk; CA-Global-140 blocks high sign-in risk outright, because AiTM phishing can replay a satisfied MFA claim. CA-Global-080 forces password change plus MFA for medium and high user risk for members only; guests are excluded because their user risk is homed in their own tenant and cannot be remediated here. CA-Global-150 blocks high user risk for everyone, which is also what stops risky guests. While the block policies are enabled, the grant policies act as a fallback layer.

**Country blocking model.** CA-Global-120 ships as a blocklist: sign-ins from the countries in the `Untrusted Countries` named location are blocked. Populate that location with a real list; a two or three country list provides almost no protection. The stronger alternative is an allowlist: include all locations, exclude a named location containing the approved operating countries, and block. Prefer the allowlist when the organization operates from a known set of countries. Country conditions rely on the internet breakout location and can be bypassed with VPNs, so treat this policy as a noise filter, not a security boundary.

**Service accounts.** CA-ServiceAccount-010 excludes a dedicated named location instead of All trusted locations. All trusted locations would silently widen service account access every time any location is marked as trusted. The service account is also pre-excluded from CA-Internal-010, CA-Internal-030 and CA-Global-090, because it cannot satisfy MFA or device compliance; the location restriction and sign-in monitoring are the compensating controls.

**Partner access.** CA-External-030 blocks external users from admin portals but deliberately does not include the serviceProvider type. Blocking serviceProvider would cut off CSP partner administration through GDAP. If the tenant has no partner relationship, add serviceProvider to the included external user types for a stricter posture.

**Agent identities.** The Agent scope is reserved in the naming model but no Agent policy ships with this baseline. Risk-based policies for workload and agent identities require Workload Identities Premium licensing, and Graph rejects them on tenants without it. Add a block-high-risk agent policy per tenant once the licensing exists.

**Platform coverage.** CA-Global-040 blocks every platform except Windows, macOS, iOS and Android. Linux is blocked by design; add it to the excluded platforms if the environment uses Linux clients.

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

Tenant-wide guardrails that are not specific to one persona: block legacy authentication, block device code flow and authentication transfer, block unknown platforms and untrusted countries, risk-based controls (MFA for sign-in risk, password change for user risk, block for high risk), MFA for device registration and Intune enrollment.

### Admin

Privileged access is treated as a high-risk access path. Require MFA for all admin roles, prefer phishing-resistant authentication, restrict admin portal sessions, limit persistent role assignment via PIM, monitor privileged sign-ins, and exclude break-glass only where required.

### Internal

Employees and standard workforce users. Typical controls: MFA, compliant device requirements, token protection, app protection for mobile access, session controls for unmanaged browser access.

### External

Non-internal human users. External is preferred over Guests because it is broader: a guest account is one type of external identity. Typical controls: MFA, restricted browser sessions, blocked admin portal access, Terms of Use where required, limited resource access, guest lifecycle review.

### Agent

AI agents, Copilot agents, automation agents and agentic identities. Restrict access to required resources, block high-risk access, avoid broad permissions, monitor sign-ins, and keep agent identities separate from service accounts. This scope makes the model future-ready even if no agent identities exist yet. No Agent policy ships with this baseline because risk-based workload policies are licensing-gated.

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

1. Complete every item in the section Required tenant configuration before deployment.
2. Replace all `REPLACE-WITH-*` tokens (see Placeholders above). Exclusions are group-based: create the three security groups first, or let the IntuneManagement import create them.
3. Import via Microsoft Graph (`POST /identity/conditionalAccess/policies`) using `policies/`, or via IntuneManagement using the ready-made `intune/` package (see `intune/IMPORT-README.md`). Policies referencing a named location fail to import if the location does not exist yet.
4. Set every imported policy to **report-only** first, regardless of the `state` value in this repository, and follow the rollout model above.
5. Confirm break-glass exclusions before enabling any blocking policy.

## Disclaimer

This baseline is a starting point, not a turnkey configuration. Every control must be validated against the specific tenant, its licensing and its operational requirements before enforcement. Use at your own risk.
