#!/usr/bin/env bash
# PreCompact hook: freeze "where I actually was" to disk at the instant of
# compaction, so the SessionStart(compact) hook has something CURRENT to read
# back instead of a hand-maintained file that may be an hour stale.
#
# A PreCompact hook cannot influence the summary - it has no additionalContext,
# and Claude Code discards its systemMessage. Writing a file is the whole play.
#
# Silent on any failure. Never blocks compaction.

set +e

# stdin is a JSON object: session_id, transcript_path, cwd, hook_event_name,
# trigger ("manual" | "auto"), custom_instructions (empty when auto).
# It must be drained even if unused or the writer can block.
INPUT=$(head -c 1048576 2>/dev/null)

field() {
  printf '%s' "$INPUT" \
    | tr ',' '\n' \
    | grep "\"$1\"" \
    | head -1 \
    | sed "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/"
}

TRIGGER=$(field trigger)
TRANSCRIPT=$(field transcript_path)

OUT=".remember/precompact.md"
[ -d ".remember" ] || OUT="../.remember/precompact.md"
[ -d "$(dirname "$OUT")" ] || exit 0

{
  echo "# Frozen at compaction"
  echo ""
  echo "Written by the PreCompact hook at $(date '+%Y-%m-%d %H:%M:%S'), trigger: ${TRIGGER:-unknown}."
  echo "This is the last known position before the conversation was summarised."
  echo ""

  # cwd is the directory Claude Code was opened in, which is not always the
  # repo. Here it holds three of them, so reporting only the first one found
  # froze a stale sibling's branch while the repo being worked in went
  # unrecorded. Report every repo and let the reader pick.
  echo "## Git"
  echo ""
  REPOS=$(if git -C . rev-parse --git-dir >/dev/null 2>&1; then echo "."; else for d in */; do git -C "$d" rev-parse --git-dir >/dev/null 2>&1 && echo "$d"; done; fi)
  if [ -z "$REPOS" ]; then
    echo "no git repository under $(pwd)"
  else
    printf '%s\n' "$REPOS" | while IFS= read -r r; do
      [ -n "$r" ] || continue
      [ "$r" = "." ] || echo "repo:   $r"
      echo "branch: $(git -C "$r" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
      echo "head:   $(git -C "$r" log --oneline -1 2>/dev/null || echo '?')"
      DIRTY=$(git -C "$r" status --short 2>/dev/null | head -25)
      if [ -n "$DIRTY" ]; then
        echo "uncommitted:"
        echo "$DIRTY" | sed 's/^/  /'
      else
        echo "uncommitted: none"
      fi
      echo ""
    done
  fi

  # The prize. Which files were being touched, in order, most recent last.
  # Nothing hand-maintained can reconstruct this, and the summary drops it.
  #
  # Parsed by node, not grep: every value in the transcript is a JSON string, so
  # a command containing \" truncates a `grep -o '"command":"[^"]*"'` at the
  # first escape, and a Windows path arrives with every backslash doubled. The
  # first version of this hook produced eight lines reading `python3 \`.
  if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
    node "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/precompact-transcript.js" "$TRANSCRIPT" 2>/dev/null
  fi

  for f in ".remember/now.md" "../.remember/now.md"; do
    if [ -f "$f" ]; then
      echo ""
      echo "## Live buffer at the moment of compaction ($f)"
      echo ""
      tail -20 "$f" 2>/dev/null | sed 's/^/  /'
      break
    fi
  done
} > "$OUT" 2>/dev/null

exit 0
