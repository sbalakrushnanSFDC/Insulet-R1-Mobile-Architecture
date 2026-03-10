#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/_helpers.sh"
cd "$PROJECT_DIR"

ORG_ALIAS="${SF_TARGET_ORG:-devint2}"
OUT="metadata/org-details"

echo "=== 08 — Sharing Gap Supplemental Queries ==="
echo ""

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
            > "$OUT/$OUTFILE" 2>&1 || echo "    WARN: $LABEL query failed"
    else
        sf_json sf data query \
            --query "$QUERY" \
            --target-org "$ORG_ALIAS" \
            > "$OUT/$OUTFILE" 2>&1 || echo "    WARN: $LABEL query failed"
    fi
}

# --- Tier 1: Sharing Rule Logic ---
run_query "Sharing criteria rules (Tooling)" \
    "sharing-criteria-rules.json" \
    "SELECT Id, Name, SobjectType, AccessLevel, GroupId, UserOrGroupId FROM SharingCriteriaRule ORDER BY SobjectType, Name LIMIT 500" \
    "true"

run_query "Sharing owner rules (Tooling)" \
    "sharing-owner-rules.json" \
    "SELECT Id, Name, SobjectType, AccessLevel, GroupId, UserOrGroupId FROM SharingOwnerRule ORDER BY SobjectType, Name LIMIT 500" \
    "true"

# --- Tier 1: Muting Permission Sets ---
run_query "Muting permission sets" \
    "muting-permission-sets.json" \
    "SELECT Id, Name, Label, Description FROM MutingPermissionSet ORDER BY Name LIMIT 200"

# --- Tier 2: Territory Assignment Rules ---
run_query "Territory2 rules (active model)" \
    "territory2-rules.json" \
    "SELECT Id, Name, Territory2Id, Territory2.Name, Territory2ModelId, BooleanFilter, IsActive FROM Territory2Rule WHERE Territory2Model.State = 'Active' ORDER BY Territory2.Name LIMIT 500"

# --- Tier 2: Sharing Sets ---
run_query "Sharing sets" \
    "sharing-sets.json" \
    "SELECT Id, Name, Label FROM SharingSet ORDER BY Name LIMIT 100"

# --- Tier 2: Community Network Members ---
run_query "Network members (Trainer Portal)" \
    "network-members.json" \
    "SELECT Id, MemberId, Member.Name, Member.Profile.Name, NetworkId FROM NetworkMember WHERE NetworkId = '0DBQO0000000HvJ4AU' LIMIT 500"

# --- Tier 3: Duplicate Rules ---
run_query "Duplicate rules" \
    "duplicate-rules.json" \
    "SELECT Id, DeveloperName, MasterLabel, IsActive, SobjectType FROM DuplicateRule ORDER BY SobjectType, MasterLabel LIMIT 200"

# --- Tier 4: Transaction Security Policies ---
run_query "Transaction security policies (Tooling)" \
    "transaction-security-policies.json" \
    "SELECT Id, DeveloperName, EventName, Action, Active, Description FROM TransactionSecurityPolicy ORDER BY EventName LIMIT 200" \
    "true"

# --- Tier 4: Delegate Groups ---
run_query "Delegate groups" \
    "delegate-groups.json" \
    "SELECT Id, DeveloperName, CustomPermission.DeveloperName FROM DelegateGroup ORDER BY DeveloperName LIMIT 100"

# --- Tier 4: Login Flows (Tooling) ---
run_query "Login flows (Tooling)" \
    "login-flows.json" \
    "SELECT Id, LoginFlowId, LoginType, UserId FROM LoginFlow LIMIT 100" \
    "true"

echo ""
echo "08 — Sharing gap queries complete."
echo "     Files in $OUT/"
ls -1 "$OUT/" | grep -E "sharing|territory2|muting|duplicate|transaction|delegate|login-flow|network-member"
