#!/usr/bin/env bash
# PostToolUse hook for Read: record every image path actually shown to the model.
# This is the evidence the look-before-ocr guard checks. It records what was
# rendered into context, not what the model claims it looked at.

set -e
. "$(dirname "$0")/_hookjson.sh"
INPUT=$(cat)
P=$(echo "$INPUT" | hookjson file_path)

case "$(echo "$P" | tr '[:upper:]' '[:lower:]')" in
  *.png|*.jpg|*.jpeg|*.webp|*.gif)
    mkdir -p "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
    echo "$P" | tr '\\' '/' | tr '[:upper:]' '[:lower:]' >> "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.looked-at.log"
    ;;
esac

exit 0
