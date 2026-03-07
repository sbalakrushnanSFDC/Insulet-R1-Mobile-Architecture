#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/_helpers.sh"
cd "$PROJECT_DIR"

ORG_ALIAS="${SF_TARGET_ORG:-devint2}"
MANIFESTS_DIR="metadata/manifests"
REPORT_FILE="docs/retrieval-report.md"

CHUNKS=(
    "package-core.xml"
    "package-security.xml"
    "package-datamodel.xml"
    "package-automation.xml"
    "package-ui.xml"
    "package-integration.xml"
)

echo "=== 04 — Retrieve Metadata (Chunked) ==="
echo ""

cat > "$REPORT_FILE" <<'HEADER'
# Metadata Retrieval Report

| Chunk | Manifest | Status | Details |
|-------|----------|--------|---------|
HEADER

TOTAL_OK=0
TOTAL_FAIL=0

for CHUNK in "${CHUNKS[@]}"; do
    MANIFEST="$MANIFESTS_DIR/$CHUNK"
    CHUNK_NAME="${CHUNK%.xml}"

    if [ ! -f "$MANIFEST" ]; then
        echo "  SKIP: $MANIFEST not found"
        echo "| $CHUNK_NAME | $CHUNK | SKIP | Manifest not found |" >> "$REPORT_FILE"
        continue
    fi

    echo "--- Retrieving $CHUNK_NAME ---"
    LOG_FILE="/tmp/retrieve-${CHUNK_NAME}.log"

    if sf_json sf project retrieve start \
        --manifest "$MANIFEST" \
        --target-org "$ORG_ALIAS" \
        > "$LOG_FILE" 2>&1; then

        COMPONENT_COUNT=$(python3 -c "
import json
with open('$LOG_FILE') as f:
    d = json.load(f)
files = d.get('result',{}).get('files',[])
print(len(files))
" 2>/dev/null || echo "?")

        echo "  OK: $COMPONENT_COUNT components"
        echo "| $CHUNK_NAME | $CHUNK | OK | $COMPONENT_COUNT components |" >> "$REPORT_FILE"
        TOTAL_OK=$((TOTAL_OK + 1))
    else
        ERR_MSG=$(python3 -c "
import json
with open('$LOG_FILE') as f:
    d = json.load(f)
msg = d.get('message','') or d.get('name','unknown error')
print(msg[:120])
" 2>/dev/null || tail -1 "$LOG_FILE" 2>/dev/null || echo "unknown error")

        echo "  FAIL: $ERR_MSG"
        echo "| $CHUNK_NAME | $CHUNK | FAIL | $ERR_MSG |" >> "$REPORT_FILE"
        TOTAL_FAIL=$((TOTAL_FAIL + 1))

        echo "    Attempting individual type fallback..."
        python3 - "$MANIFEST" "$ORG_ALIAS" "$REPORT_FILE" <<'FALLBACK_PY'
import xml.etree.ElementTree as ET, subprocess, sys, json, os

manifest_file = sys.argv[1]
org_alias = sys.argv[2]
report_file = sys.argv[3]

ns = {"md": "http://soap.sforce.com/2006/04/metadata"}
tree = ET.parse(manifest_file)
root = tree.getroot()

for type_elem in root.findall("md:types", ns):
    name_elem = type_elem.find("md:name", ns)
    if name_elem is None:
        continue
    md_type = name_elem.text

    print(f"    Fallback: retrieving {md_type} individually...")
    cmd = ["sf", "project", "retrieve", "start",
           "--metadata", md_type,
           "--target-org", org_alias,
           "--json"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode == 0:
        try:
            d = json.loads(result.stdout)
            cnt = len(d.get("result", {}).get("files", []))
            print(f"      OK: {cnt} components")
            with open(report_file, "a") as f:
                f.write(f"| (fallback) | {md_type} | OK | {cnt} components |\n")
        except Exception:
            print(f"      OK (count unknown)")
    else:
        err = result.stderr[:100] if result.stderr else "unknown"
        print(f"      FAIL: {err}")
        with open(report_file, "a") as f:
            f.write(f"| (fallback) | {md_type} | FAIL | {err[:100]} |\n")
FALLBACK_PY
    fi
    echo ""
done

echo "" >> "$REPORT_FILE"
echo "**Total: $TOTAL_OK succeeded, $TOTAL_FAIL failed (with fallbacks attempted)**" >> "$REPORT_FILE"

echo ""
echo "04 — Retrieval complete. $TOTAL_OK OK, $TOTAL_FAIL FAIL."
echo "     Report: $REPORT_FILE"
