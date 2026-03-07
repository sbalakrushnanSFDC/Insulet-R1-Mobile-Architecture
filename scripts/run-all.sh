#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

export SF_TARGET_ORG="${SF_TARGET_ORG:-devint2}"

echo "============================================"
echo " DevInt2 Metadata Snapshot — Full Run"
echo " Target org: $SF_TARGET_ORG"
echo " Started:    $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "============================================"
echo ""

STEPS=(
    "01-validate-auth.sh"
    "02-capture-fingerprint.sh"
    "03-inventory-metadata.sh"
    "04-retrieve-chunks.sh"
    "05-org-details-queries.sh"
    "06-generate-inventory.sh"
    "07-report-anomalies.sh"
)

PASS=0
FAIL=0

for STEP in "${STEPS[@]}"; do
    echo ""
    echo ">>>>>>>>>> $STEP <<<<<<<<<<"
    if bash "$SCRIPT_DIR/$STEP"; then
        PASS=$((PASS + 1))
    else
        echo "WARN: $STEP exited with non-zero status"
        FAIL=$((FAIL + 1))
    fi
done

echo ""
echo "============================================"
echo " Complete: $PASS passed, $FAIL had warnings"
echo " Finished: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "============================================"
echo ""
echo "Key outputs:"
echo "  docs/INVENTORY.md       — component counts and org summary"
echo "  docs/ANOMALIES.md       — errors and gaps"
echo "  docs/retrieval-report.md — per-chunk retrieval status"
echo "  docs/fingerprint.json   — org fingerprint"
echo "  force-app/              — retrieved metadata source"
echo "  metadata/org-details/   — SOQL query outputs"
