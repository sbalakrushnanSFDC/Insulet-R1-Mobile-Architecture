#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/_helpers.sh"
cd "$PROJECT_DIR"

echo "=== 02 — Capture Org Fingerprint ==="

python3 - <<'PYEOF'
import json, datetime, os

with open("docs/org.json") as f:
    data = json.load(f)

result = data.get("result", {})

fingerprint = {
    "capturedAt": datetime.datetime.utcnow().isoformat() + "Z",
    "sfCliVersion": os.popen("sf --version 2>/dev/null").read().strip(),
    "nodeVersion": os.popen("node --version 2>/dev/null").read().strip(),
    "orgId": result.get("id", ""),
    "instanceUrl": result.get("instanceUrl", ""),
    "username": result.get("username", ""),
    "alias": result.get("alias", ""),
    "apiVersion": result.get("apiVersion", ""),
    "clientId": result.get("clientId", ""),
    "connectedStatus": result.get("connectedStatus", ""),
}

with open("docs/fingerprint.json", "w") as f:
    json.dump(fingerprint, f, indent=2)

print("Org Fingerprint")
print("=" * 50)
for k, v in fingerprint.items():
    print(f"  {k:20s}: {v}")
print()
print("Saved to docs/fingerprint.json")
PYEOF

echo ""
echo "02 — Fingerprint capture complete."
