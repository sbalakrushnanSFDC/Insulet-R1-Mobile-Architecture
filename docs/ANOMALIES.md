# Retrieval Anomalies & Gaps — DevInt2 Sandbox

Generated: 2026-03-06T01:49:01.285501Z

## Retrieval Failures

No retrieval failures recorded.

## Query Anomalies

- **remote-site-settings.json**: query returned status 1
  - Error: 
SiteName, EndpointUrl, IsActive FROM RemoteSiteSetting ORDER BY SiteName
                                     ^
ERROR at Row:1:Column:49
sObject type 'RemoteSiteSetting' is not supported. If you are 

## Known Limitations

- Reports, dashboards, and email templates in **private folders** cannot be retrieved via Metadata API.
- **Assignment rules** are not deployable via Metadata API; document manually.
- **Managed package metadata** from installed packages is read-only; only unlocked/customizable components are retrievable.
- **Large Profile/PermissionSet retrievals** may time out; use smaller batches if needed.
- **ReportFolder** may not appear in `sf org list metadata-types` due to known CLI bug.
- Some **legacy Workflow/ProcessBuilder** metadata uses different type names.

## Recommended Next Steps

1. For any FAIL items above, attempt targeted single-type retrieves.
2. For Tooling API query failures, check user permissions (System Administrator profile recommended).
3. Consider retrieving Reports and Dashboards by listing public folders first, then retrieving per folder.
4. For very large orgs, retrieve CustomObject per-object instead of wildcard.

## Gap-Fill Run Anomalies — March 9, 2026

### Retrieval Failures (Expected)
- **SiteDotCom**: `Trainer_Portal.site` uses LWR "Build Your Own" template which does not support Metadata API retrieval. Community content accessible via ExperienceBundle.
- **ConnectedApp (4 managed packages)**: Odaseva_for_Salesforce, DocuSign, Copado_DevOps_EMEA2, CPQIntegrationUserApp fail with "Metadata API received improper input" — managed package restriction, expected.

### SOQL Query Failures (Fixed/Fallback Used)
- **SharingCriteriaRule / SharingOwnerRule**: Not queryable via standard SOQL or Tooling API. Evidence obtained by parsing retrieved SharingRules XML directly.
- **SharingSet**: Not queryable via SOQL. Evidence obtained from retrieved XML file.
- **Territory2Rule**: Not separately queryable. No rules exist; assignment is entirely manual.
- **DelegateGroup**: Not queryable via standard SOQL. Retrieved via Tooling API and metadata XML.
- **LoginFlow**: Not queryable via Tooling API at API v66 in this org configuration. Not applicable.
- **MutingPermissionSet**: Query fixed (removed invalid `Name` field); returns 0 records — confirmed none exist.
- **TransactionSecurityPolicy**: Field names differ between API versions; obtained 0-record result via standard SOQL.

### Confirmed Absences (Findings Closed)
- **RestrictionRule**: 0 components retrieved — confirmed absent
- **ScopingRule**: Not in 344-type org catalog — confirmed not supported/not in use at API v66
- **MutingPermissionSet**: 0 records — confirmed no muting mechanism in use
- **TransactionSecurityPolicy**: 0 records — governance gap (Finding F-017 in R2 assessment)
