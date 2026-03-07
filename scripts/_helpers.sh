#!/usr/bin/env bash
# Shared helpers for all scripts.
# Source this file: . "$(dirname "$0")/_helpers.sh"

export PATH="/Users/sbalakrushnan/.nvm/versions/node/v22.20.0/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# sf_json CMD [ARGS...] > file.json
# Runs an sf command with --json, strips any non-JSON preamble (CLI warnings).
sf_json() {
    "$@" --json 2>/dev/null | python3 -c "
import sys, re, json
raw = sys.stdin.read()
match = re.search(r'(\{.*\})', raw, re.DOTALL)
if match:
    print(match.group(1))
else:
    print(raw)
"
}
