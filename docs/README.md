# DevInt2 Metadata Snapshot

Reproducible metadata snapshot of the **Insulet devint2** Salesforce sandbox for architecture review and analysis.

## Target Org

- **Alias**: devint2
- **Instance**: https://omnipod--devint2.sandbox.my.salesforce.com
- **Org ID**: 00Dbb000006gUxVEAU
- **Username**: sbalakrushnan@insulet.com.nextgen.devint2
- **API Version**: 66.0
- **Type**: Unlimited Edition (Sandbox)

## Prerequisites

- Salesforce CLI (`sf`) v2.x
- Node.js 18+
- Authenticated org: `sf org login web --alias devint2 --instance-url https://test.salesforce.com`

## How to Run

```bash
cd insulet-devint2-metadata-snapshot

# Full run (all steps)
./scripts/run-all.sh

# Or step by step:
./scripts/01-validate-auth.sh
./scripts/02-capture-fingerprint.sh
./scripts/03-inventory-metadata.sh
./scripts/04-retrieve-chunks.sh
./scripts/05-org-details-queries.sh
./scripts/06-generate-inventory.sh
./scripts/07-report-anomalies.sh
```

## What Gets Retrieved

### Metadata (force-app/)

Retrieved via `sf project retrieve start` using 8 chunked manifests:

| Manifest | Contents |
|----------|----------|
| package-core.xml | CustomLabels, GlobalValueSets, StandardValueSets, Settings, StaticResources, Translations |
| package-security.xml | Profiles, PermissionSets, PermissionSetGroups, AuthProviders, ConnectedApps, Roles, **SharingRules** (407 files), **Group**, **Queue**, Territory2Model, Territory2Type, SharingSet, DelegateGroup, MutingPermissionSet, TransactionSecurityPolicy |
| package-datamodel.xml | CustomObjects (with fields, record types, layouts, validation rules, compact layouts) |
| package-automation.xml | ApexClasses, ApexTriggers, Flows, Workflow rules/field updates/alerts, ApexPages, PlatformEvents |
| package-ui.xml | FlexiPages, LWC bundles, Aura bundles, CustomTabs, CustomApplications, QuickActions |
| package-integration.xml | NamedCredentials, ExternalCredentials, RemoteSiteSettings, CustomMetadata, EmailTemplates |
| package-community.xml | ExperienceBundle, Network, CustomSite, SiteDotCom, CspTrustedSite |
| package-governance.xml | RestrictionRule, DuplicateRule, FlowDefinition, ApexEmailNotifications |

### Org Details (metadata/org-details/)

SOQL queries against standard and Tooling API:
- Installed packages
- Apex classes/triggers (names, status, API version)
- Flows (name, type, status)
- Entity definitions + field counts
- Permission sets/groups
- Connected apps, named credentials, auth providers
- Remote site settings, custom metadata types
- Active users by profile
- Recent setup audit trail entries

## Outputs

| File | Purpose |
|------|---------|
| `docs/fingerprint.json` | Org identity and capture timestamp |
| `docs/INVENTORY.md` | Component counts, packages, user summary |
| `docs/ANOMALIES.md` | Retrieval failures, query errors, known gaps |
| `docs/retrieval-report.md` | Per-chunk retrieval status |
| `docs/org.json` | Raw sf org display output |
| `docs/SHARING_ACCESS_ASSESSMENT.md` | Sharing, visibility & access-control assessment (R1v1.1) |

## Limitations

- Reports, dashboards, and email templates in private folders are not retrievable
- Managed package metadata (from ISV packages) is read-only
- Some metadata types may fail wildcard retrieval; fallback to per-type retrieve is automatic
- This is a read-only snapshot; no changes are made to the org

**Note:** Sharing rule XML definitions (407 files in `force-app/main/default/sharingRules/`) are included in the local metadata snapshot via package-security.xml.
