#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/_helpers.sh"
cd "$PROJECT_DIR"

ORG_ALIAS="${SF_TARGET_ORG:-devint2}"

echo "=== 01 — Validate Auth ==="
echo "Project dir: $PROJECT_DIR"
echo "Target org:  $ORG_ALIAS"
echo ""

echo "--- SF CLI version ---"
sf --version 2>/dev/null
echo ""

echo "--- Node version ---"
node --version 2>/dev/null
echo ""

echo "--- Org display ---"
sf_json sf org display --target-org "$ORG_ALIAS" > docs/org.json || true
sf org display --target-org "$ORG_ALIAS" 2>/dev/null > docs/org.txt || true

CONNECTED=$(python3 -c "
import json, sys
with open('docs/org.json') as f:
    d = json.load(f)
print(d.get('result',{}).get('connectedStatus','UNKNOWN'))
" 2>/dev/null || echo "PARSE_ERROR")

echo "Connected status: $CONNECTED"

if [ "$CONNECTED" != "Connected" ]; then
    echo "ERROR: Org is not connected. Run: sf org login web --alias $ORG_ALIAS --instance-url https://test.salesforce.com"
    exit 1
fi

echo ""
echo "01 — Auth validation PASSED."
