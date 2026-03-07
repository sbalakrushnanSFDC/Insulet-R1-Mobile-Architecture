#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/_helpers.sh"
cd "$PROJECT_DIR"

ORG_ALIAS="${SF_TARGET_ORG:-devint2}"
OUT="metadata/org-details"

echo "=== 03 — Inventory Metadata ==="

echo "--- Listing all metadata types ---"
sf_json sf org list metadata-types --target-org "$ORG_ALIAS" > "$OUT/metadata-types.json" || echo "WARN: metadata-types failed"
TYPE_COUNT=$(python3 -c "
import json
with open('$OUT/metadata-types.json') as f:
    d = json.load(f)
types = d.get('result',{}).get('metadataObjects',[])
print(len(types))
" 2>/dev/null || echo "?")
echo "  Found $TYPE_COUNT metadata types."

TYPES_TO_LIST=(
    "ApexClass"
    "ApexTrigger"
    "ApexPage"
    "ApexComponent"
    "Flow"
    "CustomObject"
    "Profile"
    "PermissionSet"
    "PermissionSetGroup"
    "CustomApplication"
    "FlexiPage"
    "LightningComponentBundle"
    "AuraDefinitionBundle"
    "CustomTab"
    "NamedCredential"
    "RemoteSiteSetting"
    "ConnectedApp"
    "AuthProvider"
    "StaticResource"
    "EmailTemplate"
    "CustomMetadata"
    "Layout"
    "ValidationRule"
    "WorkflowRule"
    "QuickAction"
    "CustomLabel"
)

for TYPE in "${TYPES_TO_LIST[@]}"; do
    SAFE_NAME=$(echo "$TYPE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    echo "  Listing $TYPE..."
    sf_json sf org list metadata --metadata-type "$TYPE" --target-org "$ORG_ALIAS" > "$OUT/${SAFE_NAME}.json" || echo "    WARN: $TYPE listing failed"
done

echo ""
echo "03 — Inventory complete. Files in $OUT/"
ls -1 "$OUT/"
