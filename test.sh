#!/usr/bin/env bash
# Smoke test: feed each blocking hook a fake tool call and check the exit code.
# Run from the repo root: bash test.sh
set -u
H="$(dirname "$0")/hooks"
FAIL=0
expect() { # expect <code> <hook> <json>
  printf '%s' "$3" | bash "$H/$2" >/dev/null 2>&1; got=$?
  if [ "$got" = "$1" ]; then echo "ok   $2 -> $got"; else echo "FAIL $2 expected $1 got $got"; FAIL=1; fi
}
DASH=$(printf '\xe2\x80\x94')
expect 2 no-em-dash.sh "{\"tool_input\":{\"content\":\"a ${DASH} b\"}}"
expect 0 no-em-dash.sh '{"tool_input":{"content":"a - b"}}'
expect 0 first-person-voice-warn.sh '{"tool_input":{"file_path":"x.md","content":"I hope this finds you well"}}'
expect 0 git-push-guard.sh '{"tool_input":{"command":"git push origin main"}}'
TMP=$(mktemp -d); printf '%%PDF-1.4' > "$TMP/a.pdf"
CLAUDE_CONFIG_DIR="$TMP" expect 2 look-before-ocr.sh "{\"tool_input\":{\"command\":\"pdftotext $TMP/a.pdf -\"}}"
CLAUDE_CONFIG_DIR="$TMP" expect 2 look-before-ocr.sh "{\"tool_input\":{\"command\":\"python -c x \\\"$TMP/a.pdf\\\" pdfplumber\"}}"
expect 0 look-before-ocr.sh '{"tool_input":{"command":"ls"}}'

rm -rf "$TMP"
exit $FAIL
