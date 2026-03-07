#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/_helpers.sh"
cd "$PROJECT_DIR"

echo "=== 07 — Report Anomalies ==="

python3 - <<'PYEOF'
import json, os, datetime

OUT = "metadata/org-details"
ANOMALIES_FILE = "docs/ANOMALIES.md"
REPORT_FILE = "docs/retrieval-report.md"

lines = []
lines.append("# Retrieval Anomalies & Gaps — DevInt2 Sandbox")
lines.append("")
lines.append(f"Generated: {datetime.datetime.utcnow().isoformat()}Z")
lines.append("")

# Check retrieval report for failures
lines.append("## Retrieval Failures")
lines.append("")
if os.path.isfile(REPORT_FILE):
    with open(REPORT_FILE) as f:
        report = f.read()
    fail_lines = [l for l in report.split("\n") if "FAIL" in l]
    if fail_lines:
        lines.append("| Chunk | Type | Details |")
        lines.append("|-------|------|---------|")
        for fl in fail_lines:
            lines.append(fl)
        lines.append("")
    else:
        lines.append("No retrieval failures recorded.")
        lines.append("")
else:
    lines.append("Retrieval report not found (docs/retrieval-report.md).")
    lines.append("")

# Check for empty/failed query outputs
lines.append("## Query Anomalies")
lines.append("")
anomaly_count = 0
for fname in sorted(os.listdir(OUT)):
    fpath = os.path.join(OUT, fname)
    if not fname.endswith(".json"):
        continue
    try:
        with open(fpath) as f:
            d = json.load(f)
        status = d.get("status", 0)
        if status != 0:
            lines.append(f"- **{fname}**: query returned status {status}")
            msg = d.get("message", "")
            if msg:
                lines.append(f"  - Error: {msg[:200]}")
            anomaly_count += 1
    except json.JSONDecodeError:
        lines.append(f"- **{fname}**: invalid JSON (query likely failed)")
        anomaly_count += 1
    except Exception as e:
        lines.append(f"- **{fname}**: could not parse — {e}")
        anomaly_count += 1

if anomaly_count == 0:
    lines.append("No query anomalies detected.")
lines.append("")

# Known limitations
lines.append("## Known Limitations")
lines.append("")
lines.append("- Reports, dashboards, and email templates in **private folders** cannot be retrieved via Metadata API.")
lines.append("- **Assignment rules** are not deployable via Metadata API; document manually.")
lines.append("- **Managed package metadata** from installed packages is read-only; only unlocked/customizable components are retrievable.")
lines.append("- **Large Profile/PermissionSet retrievals** may time out; use smaller batches if needed.")
lines.append("- **ReportFolder** may not appear in `sf org list metadata-types` due to known CLI bug.")
lines.append("- Some **legacy Workflow/ProcessBuilder** metadata uses different type names.")
lines.append("")

# Recommended next steps
lines.append("## Recommended Next Steps")
lines.append("")
lines.append("1. For any FAIL items above, attempt targeted single-type retrieves.")
lines.append("2. For Tooling API query failures, check user permissions (System Administrator profile recommended).")
lines.append("3. Consider retrieving Reports and Dashboards by listing public folders first, then retrieving per folder.")
lines.append("4. For very large orgs, retrieve CustomObject per-object instead of wildcard.")
lines.append("")

with open(ANOMALIES_FILE, "w") as f:
    f.write("\n".join(lines))

print(f"Anomalies report: {ANOMALIES_FILE}")
print(f"  Retrieval failures flagged: {len([l for l in lines if 'FAIL' in l])}")
print(f"  Query anomalies: {anomaly_count}")
PYEOF

echo ""
echo "07 — Anomalies report complete."
