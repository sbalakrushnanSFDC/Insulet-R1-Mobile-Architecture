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
