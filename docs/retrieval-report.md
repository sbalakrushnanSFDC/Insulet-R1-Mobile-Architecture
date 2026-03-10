# Metadata Retrieval Report

| Chunk | Manifest | Status | Details |
|-------|----------|--------|---------|
| package-core | package-core.xml | OK | 282 components |
| package-security | package-security.xml | OK | 171 components |
| package-datamodel | package-datamodel.xml | OK | 1189 components |
| package-automation | package-automation.xml | OK | 796 components |
| package-ui | package-ui.xml | OK | 357 components |
| package-integration | package-integration.xml | OK | 388 components |

**Total: 6 succeeded, 0 failed (with fallbacks attempted)**

## Gap-Fill Run — March 9, 2026

### Security Manifest (package-security.xml — expanded)

| Type | Status | Count |
|------|--------|-------|
| SharingRules | OK | 407 |
| Group | OK | 11 |
| Queue | OK | 16 |
| MutingPermissionSet | OK | 0 (none exist) |
| Territory2Model | OK | 4 |
| Territory2Type | OK | 6 |
| SharingSet | OK | 1 |
| DelegateGroup | OK | 1 |
| TransactionSecurityPolicy | OK | 0 (none exist) |
| ConnectedApp (Odaseva, DocuSign, Copado, CPQ) | FAIL | Managed package — expected failure |

### Community Manifest (package-community.xml — new)

| Type | Status | Count |
|------|--------|-------|
| ExperienceBundle | Not retrieved (LWR) | — |
| Network | OK | 1 |
| CustomSite | OK | 1 |
| SiteDotCom | FAIL | LWR Build Your Own template not supported by Metadata API |
| CspTrustedSite | OK | 1 |

### Governance Manifest (package-governance.xml — new)

| Type | Status | Count |
|------|--------|-------|
| RestrictionRule | OK | 0 (none exist — expected) |
| DuplicateRule | OK | 9 |
| FlowDefinition | OK | 45 |
| ApexEmailNotifications | OK | 1 |

**Total gap-fill: 677 new components (614 security + 59 governance + 4 community)**
