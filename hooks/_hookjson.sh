#!/usr/bin/env bash
# Shared JSON field reader for the hooks. jq is NOT installed on this machine,
# so every hook that called it fell through silently and enforced nothing from
# 2026-08-17 until this was found on 2026-08-20. Python is present; use it.
#
# Sets HOOKJSON_OK=1 when a working interpreter was found. Blocking hooks must
# check that and fail loud, because a guard that cannot parse its input has to
# say so rather than wave the call through.
#
# Usage:  VALUE=$(echo "$INPUT" | hookjson new_string content)
# Returns the first key under .tool_input that has a non-empty value.

HOOKJSON_PY=$(command -v python 2>/dev/null || command -v python3 2>/dev/null || command -v py 2>/dev/null || echo "")
if [ -n "$HOOKJSON_PY" ]; then
  HOOKJSON_OK=1
else
  HOOKJSON_OK=0
fi

hookjson() {
  [ "$HOOKJSON_OK" = "1" ] || { echo ""; return 0; }
  HOOKJSON_KEYS="$*" "$HOOKJSON_PY" -c 'import json,os,sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
ti = d.get("tool_input") or {}
for k in os.environ.get("HOOKJSON_KEYS", "").split():
    v = ti.get(k)
    if v:
        sys.stdout.write(str(v))
        break
' 2>/dev/null || echo ""
}
