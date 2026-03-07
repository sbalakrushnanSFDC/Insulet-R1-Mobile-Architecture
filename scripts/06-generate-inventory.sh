#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/_helpers.sh"
cd "$PROJECT_DIR"

echo "=== 06 — Generate Inventory ==="

python3 - <<'PYEOF'
import json, os, glob, datetime

OUT = "metadata/org-details"
INVENTORY = "docs/INVENTORY.md"

def safe_load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return {}

def count_records(path):
    d = safe_load(path)
    records = d.get("result", d).get("records", d.get("result", []))
    if isinstance(records, list):
        return len(records)
    return 0

def get_records(path):
    d = safe_load(path)
    records = d.get("result", d).get("records", d.get("result", []))
    if isinstance(records, list):
        return records
    return []

lines = []
lines.append("# Org Inventory — DevInt2 Sandbox")
lines.append("")
lines.append(f"Generated: {datetime.datetime.utcnow().isoformat()}Z")
lines.append("")

# Org info
org = safe_load(f"{OUT}/organization.json")
org_rec = (org.get("result", {}).get("records", [{}]) or [{}])[0]
lines.append("## Org Details")
lines.append("")
lines.append(f"| Field | Value |")
lines.append(f"|-------|-------|")
for k in ["Id", "Name", "OrganizationType", "IsSandbox", "InstanceName", "NamespacePrefix"]:
    lines.append(f"| {k} | {org_rec.get(k, 'N/A')} |")
lines.append("")

# Metadata types
mt = safe_load(f"{OUT}/metadata-types.json")
mt_list = mt.get("result", {}).get("metadataObjects", [])
lines.append(f"## Metadata Types Available: {len(mt_list)}")
lines.append("")

# Component counts
lines.append("## Component Counts")
lines.append("")
lines.append("| Type | Count |")
lines.append("|------|-------|")

inventory_files = {
    "Apex Classes": "apex-classes-detail.json",
    "Apex Triggers": "apex-triggers-detail.json",
    "Flows": "flows-detail.json",
    "Permission Sets": "permission-sets-summary.json",
    "Permission Set Groups": "permission-set-groups.json",
    "Connected Apps": "connected-apps.json",
    "Named Credentials": "named-credentials.json",
    "Auth Providers": "auth-providers.json",
    "Remote Site Settings": "remote-site-settings.json",
    "Custom Metadata Types": "custom-metadata-types.json",
    "Installed Packages": "installed-packages.json",
}
for label, fname in inventory_files.items():
    cnt = count_records(f"{OUT}/{fname}")
    lines.append(f"| {label} | {cnt} |")

# Entity definitions
entity_cnt = count_records(f"{OUT}/entity-definitions.json")
lines.append(f"| Custom/Customizable Objects | {entity_cnt} |")
lines.append("")

# Installed packages detail
pkgs = get_records(f"{OUT}/installed-packages.json")
if pkgs:
    lines.append("## Installed Packages")
    lines.append("")
    lines.append("| Package | Version |")
    lines.append("|---------|---------|")
    for p in pkgs:
        sp = p.get("SubscriberPackage", {}) or {}
        spv = p.get("SubscriberPackageVersion", {}) or {}
        name = sp.get("Name", "?")
        ver = f"{spv.get('MajorVersion','?')}.{spv.get('MinorVersion','?')}"
        lines.append(f"| {name} | {ver} |")
    lines.append("")

# Active users by profile
users = get_records(f"{OUT}/active-users.json")
if users:
    lines.append("## Active Users by Profile")
    lines.append("")
    lines.append("| Profile | Count |")
    lines.append("|---------|-------|")
    for u in users:
        prof = u.get("profileName", None)
        if prof is None:
            prof_obj = u.get("Profile", {}) or {}
            prof = prof_obj.get("Name", "N/A") if isinstance(prof_obj, dict) else "N/A"
        cnt = u.get("cnt", 0)
        lines.append(f"| {prof} | {cnt} |")
    lines.append("")

# Retrieved metadata files
lines.append("## Retrieved Metadata (force-app)")
lines.append("")
force_app = "force-app/main/default"
if os.path.isdir(force_app):
    for d in sorted(os.listdir(force_app)):
        full = os.path.join(force_app, d)
        if os.path.isdir(full):
            file_count = sum(1 for _ in glob.glob(f"{full}/**/*", recursive=True) if os.path.isfile(_))
            lines.append(f"- **{d}/**: {file_count} files")
lines.append("")

with open(INVENTORY, "w") as f:
    f.write("\n".join(lines))

print(f"Inventory written to {INVENTORY}")
print(f"  Metadata types: {len(mt_list)}")
print(f"  Sections: {sum(1 for l in lines if l.startswith('## '))}")
PYEOF

echo ""
echo "06 — Inventory generation complete."
