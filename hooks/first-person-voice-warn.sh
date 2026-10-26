#!/usr/bin/env bash
# PreToolUse hook for Write/Edit on .md / .html / .txt files: WARN (not
# block) if the write contains obvious first-person user-voice patterns.
# Rule: never draft outbound copy in the user's own voice unless they ask for it.
#
# Warning-only because false positives are common (technical prose uses
# "we" and "I" all the time). This just flags for a second look. Exit 0
# always.

set +e
. "$(dirname "$0")/_hookjson.sh"
INPUT=$(cat)

if [ "$HOOKJSON_OK" != "1" ]; then
  echo "WARN: the first-person-voice hook cannot read its input - no python interpreter on PATH. It is enforcing nothing." >&2
  exit 0
fi

# Only fire on .md, .html, .txt files
PATH_STR=$(echo "$INPUT" | hookjson file_path)
if ! echo "$PATH_STR" | grep -qiE '\.(md|html|txt|mdx)$'; then
  exit 0
fi

NEW=$(echo "$INPUT" | hookjson new_string content)

# Conservative first-person patterns that scream "AI-drafted outreach copy"
# Avoid single-word "I" or "we" because those are legit in most prose.
PATTERNS='(I.?m reaching out|I.?d love to|I.?ve been running|I do this|reaching out to you|my team and I|as (the )?founder of|excited to (share|announce)|I wanted to (share|reach|introduce)|I hope this (finds|email))'

if echo "$NEW" | grep -qiE "$PATTERNS"; then
  echo "WARN: first-person / user-voice phrasing detected in $PATH_STR. Rule: never draft copy in the user's voice unless they explicitly ask for it. Consider a neutral template with placeholders they can personalise." >&2
fi

exit 0
