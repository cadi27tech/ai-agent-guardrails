#!/usr/bin/env bash
# PreToolUse hook for Bash: refuse to extract text from a PDF that has not been
# looked at page by page.
#
# Why this exists. On 2026-08-19 four attached PDFs were reasoned about without
# being opened, and six conclusions were wrong; three of the six findings were in
# pen, which no text extraction can see. On 2026-08-20 a previous session's claim
# that a 57-page pack had been "read page by page" was reused as proof of
# coverage. A claim is not evidence. This hook makes the evidence mechanical.
#
# It blocks any text-extraction call against a .pdf unless render-all-pages.py
# has produced a manifest for that exact file and every page image in that
# manifest appears in the looked-at log, which is written by the Read hook and
# therefore records what was actually put in front of the model.

set -e
. "$(dirname "$0")/_hookjson.sh"
INPUT=$(cat)

if [ "$HOOKJSON_OK" != "1" ]; then
  echo "BLOCKED: the look-before-OCR guard cannot read its input - no python interpreter on PATH. Fix the hook rather than extracting unchecked." >&2
  exit 2
fi

CMD=$(echo "$INPUT" | hookjson command)

# Only interested in text extraction from PDFs.
echo "$CMD" | grep -qiE 'tesseract|pytesseract|pdftotext|pdfplumber|extract_text|get_text|PyPDF|pdfminer' || exit 0
echo "$CMD" | grep -qiE '\.pdf' || exit 0

PDF=$(echo "$CMD" | grep -oiE "[^'\"]+\.pdf" | head -1)
# A quoted path may contain spaces; an unquoted one ends at the first space, and
# the quoted pattern alone would swallow the command name in front of it, find
# no such file, and wave the call through.
[ -f "$PDF" ] || PDF=$(echo "$CMD" | grep -oiE "[^'\" ]+\.pdf" | head -1)
[ -n "$PDF" ] || exit 0
[ -f "$PDF" ] || exit 0

SUM=$(md5sum "$PDF" | cut -d' ' -f1)
MAN="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/render-manifests/$SUM.manifest"

if [ ! -f "$MAN" ]; then
  echo "BLOCKED: no page renders exist for this PDF, so nothing has been looked at." >&2
  echo "Render every page first, then look at them:" >&2
  echo "  python \"${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/render-all-pages.py\" \"$PDF\"" >&2
  echo "Then Read each PNG it lists. Text extraction cannot see handwriting, and a scan with no text layer returns silence that reads as absence." >&2
  exit 2
fi

LOG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.looked-at.log"
touch "$LOG"

MISSING=0
FIRST=""
while IFS= read -r PAGE; do
  PAGE=${PAGE%$'\r'}
  [ -n "$PAGE" ] || continue
  if ! grep -qxF "$PAGE" "$LOG"; then
    MISSING=$((MISSING+1))
    [ -n "$FIRST" ] || FIRST="$PAGE"
  fi
done < "$MAN"

if [ "$MISSING" -gt 0 ]; then
  TOTAL=$(grep -c . "$MAN")
  echo "BLOCKED: $MISSING of $TOTAL pages of this PDF have not been looked at." >&2
  echo "Read them before extracting any text. Start with: $FIRST" >&2
  echo "Trust the rendered page over the extracted string. Where they disagree, the page wins." >&2
  exit 2
fi

exit 0
