#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/_helpers.sh"
cd "$PROJECT_DIR"

ORG_ALIAS="${SF_TARGET_ORG:-devint2}"
OUT="metadata/org-details"

echo "=== 05 — Org Detail Queries ==="

run_query() {
    local LABEL="$1"
    local OUTFILE="$2"
    local QUERY="$3"
    local USE_TOOLING="${4:-false}"

    echo "  $LABEL -> $OUTFILE"

    if [ "$USE_TOOLING" = "true" ]; then
        sf_json sf data query \
            --query "$QUERY" \
            --target-org "$ORG_ALIAS" \
            --use-tooling-api \
            > "$OUT/$OUTFILE" || echo "    WARN: $LABEL query failed"
    else
        sf_json sf data query \
            --query "$QUERY" \
            --target-org "$ORG_ALIAS" \
            > "$OUT/$OUTFILE" || echo "    WARN: $LABEL query failed"
    fi
}

run_query "Installed packages" \
    "installed-packages.json" \
    "SELECT Id, SubscriberPackage.Name, SubscriberPackageVersion.Name, SubscriberPackageVersion.MajorVersion, SubscriberPackageVersion.MinorVersion FROM InstalledSubscriberPackage ORDER BY SubscriberPackage.Name"

run_query "Apex classes (Tooling)" \
    "apex-classes-detail.json" \
    "SELECT Id, Name, Status, ApiVersion, LengthWithoutComments, CreatedDate, LastModifiedDate FROM ApexClass ORDER BY Name" \
    "true"

run_query "Apex triggers (Tooling)" \
    "apex-triggers-detail.json" \
    "SELECT Id, Name, Status, ApiVersion, TableEnumOrId, CreatedDate, LastModifiedDate FROM ApexTrigger ORDER BY Name" \
    "true"

run_query "Flows" \
    "flows-detail.json" \
    "SELECT Id, ApiName, Label, ProcessType, TriggerType, Status, VersionNumber, LastModifiedDate FROM FlowDefinitionView ORDER BY ApiName" \
    "true"

run_query "Entity definitions (objects)" \
    "entity-definitions.json" \
    "SELECT QualifiedApiName, Label, IsCustomSetting, IsQueryable, DurableId FROM EntityDefinition WHERE IsCustomizable = true ORDER BY QualifiedApiName LIMIT 2000"

run_query "Field counts per object" \
    "field-counts.json" \
    "SELECT EntityDefinition.QualifiedApiName, COUNT(Id) fieldCount FROM FieldDefinition GROUP BY EntityDefinition.QualifiedApiName ORDER BY COUNT(Id) DESC LIMIT 200"

run_query "Permission sets" \
    "permission-sets-summary.json" \
    "SELECT Id, Name, Label, IsOwnedByProfile, IsCustom, NamespacePrefix FROM PermissionSet WHERE IsOwnedByProfile = false ORDER BY Name LIMIT 500"

run_query "Permission set groups" \
    "permission-set-groups.json" \
    "SELECT Id, DeveloperName, MasterLabel, Status FROM PermissionSetGroup ORDER BY DeveloperName LIMIT 200"

run_query "Connected apps" \
    "connected-apps.json" \
    "SELECT Id, Name, CreatedDate FROM ConnectedApplication ORDER BY Name LIMIT 100"

run_query "Named credentials" \
    "named-credentials.json" \
    "SELECT Id, DeveloperName, Endpoint FROM NamedCredential ORDER BY DeveloperName LIMIT 100"

run_query "Auth providers" \
    "auth-providers.json" \
    "SELECT Id, DeveloperName, ProviderType, FriendlyName FROM AuthProvider ORDER BY DeveloperName LIMIT 100"

run_query "Remote site settings" \
    "remote-site-settings.json" \
    "SELECT Id, SiteName, EndpointUrl, IsActive FROM RemoteSiteSetting ORDER BY SiteName LIMIT 200"

run_query "Custom metadata types" \
    "custom-metadata-types.json" \
    "SELECT QualifiedApiName, Label, DurableId FROM EntityDefinition WHERE QualifiedApiName LIKE '%__mdt' ORDER BY QualifiedApiName LIMIT 200"

run_query "Org info" \
    "organization.json" \
    "SELECT Id, Name, OrganizationType, IsSandbox, InstanceName, NamespacePrefix, TrialExpirationDate, CreatedDate FROM Organization LIMIT 1"

run_query "Active user count" \
    "active-users.json" \
    "SELECT Profile.Name, COUNT(Id) cnt FROM User WHERE IsActive = true GROUP BY Profile.Name ORDER BY COUNT(Id) DESC LIMIT 50"

run_query "Recently modified setup" \
    "recent-setup-changes.json" \
    "SELECT Id, CreatedBy.Name, Display, Section, CreatedDate FROM SetupAuditTrail ORDER BY CreatedDate DESC LIMIT 100"

echo ""
echo "05 — Org detail queries complete."
echo "     Files in $OUT/"
ls -1 "$OUT/" | grep -v metadata-types
