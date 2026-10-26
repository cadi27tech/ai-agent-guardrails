#!/usr/bin/env bash
# SessionStart hook: dump a compact "where were we" report so I don't need
# to reconstruct project state from scratch every session.
# Bounded output: never more than ~50 lines. Silent on any failure.

set +e

# Claude Code sends this hook a JSON object on stdin. `source` is one of
# startup | resume | clear | compact. The compact case is the one that loses
# work: the model keeps a summary of the conversation, but nothing about where
# it actually was, so anything mid-flight has to be reconstructed by reading
# files back. The COMPACT ONLY block at the bottom is what closes that.
#
# stdin must be drained even when it is not used, or the writer can block.
INPUT=$(head -c 65536 2>/dev/null)
SOURCE=$(printf '%s' "$INPUT" \
  | tr ',' '\n' \
  | grep '"source"' \
  | head -1 \
  | sed 's/.*"source"[[:space:]]*:[[:space:]]*"\([a-z]*\)".*/\1/')

CWD=$(pwd)
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")

echo "==== SESSION CONTEXT ===="
echo "cwd: $CWD"
echo "branch: $BRANCH"
[ -n "$SOURCE" ] && echo "source: $SOURCE"


# Recent activity
if [ -f ".remember/recent.md" ]; then
  echo ""
  echo "--- .remember/recent.md (last 15 lines) ---"
  tail -15 .remember/recent.md 2>/dev/null | head -15
fi
if [ -f "../.remember/recent.md" ]; then
  echo ""
  echo "--- ../.remember/recent.md (last 15 lines) ---"
  tail -15 ../.remember/recent.md 2>/dev/null | head -15
fi

# Open PRs (if this is a git repo with a GitHub remote)
if git remote -v 2>/dev/null | grep -q github.com; then
  echo ""
  echo "--- open PRs ---"
  gh pr list --state open --limit 5 --json number,title,headRefName --template '{{range .}}#{{.number}} {{.title}} ({{.headRefName}}){{"\n"}}{{end}}' 2>/dev/null || echo "(gh not available or repo not accessible)"
fi

# -- COMPACT ONLY -----------------------------------------------------------
# `recent.md` above is a daily digest - it answers "what happened yesterday",
# which is not the question after a compaction. `now.md` is the live buffer:
# timestamped, one line per step, written as the work happens. The remember
# plugin delivers it at session start and explicitly does NOT re-inject it at
# compact, which is the single biggest hole. NOW.md, if the project keeps one,
# is the hand-written counterpart: the manual steps and decisions that are not
# derivable from the code.
if [ "$SOURCE" = "compact" ]; then
  # precompact.md is written by the PreCompact hook at the instant of
  # compaction, so it is never stale. now.md is the fallback for the case
  # where PreCompact did not fire (it does not fire on the tool-output
  # clearing pass, and that pass alone can lose position).
  EMITTED=""
  for f in ".remember/precompact.md" "../.remember/precompact.md"; do
    if [ -f "$f" ]; then
      echo ""
      echo "--- $f (frozen AT compaction) - THIS IS WHERE YOU WERE ---"
      head -60 "$f" 2>/dev/null
      EMITTED=1
      break
    fi
  done
  if [ -z "$EMITTED" ]; then
    for f in ".remember/now.md" "../.remember/now.md"; do
      if [ -f "$f" ]; then
        echo ""
        echo "--- $f (live buffer, last 25 lines) - THIS IS WHERE YOU WERE ---"
        tail -25 "$f" 2>/dev/null
        break
      fi
    done
  fi
  for f in "docs/plans/NOW.md" "../docs/plans/NOW.md"; do
    if [ -f "$f" ]; then
      echo ""
      echo "--- $f (open manual steps and decisions) ---"
      head -40 "$f" 2>/dev/null
      break
    fi
  done
  echo ""
  echo "Re-read the two blocks above before deciding what to do next. They are"
  echo "the only record of in-flight work that the conversation summary drops."
fi

echo ""
echo "==== END CONTEXT ===="
