#!/usr/bin/env bash
# PreToolUse hook for Bash tool: if the command is `git push`, remind about
# the Windows SSL workaround AND run gh pr view for the current branch to
# catch pushes to a branch whose PR is already merged (one-PR-per-ask rule).
# Never blocks - just injects context. The user keeps agency.

set -e
. "$(dirname "$0")/_hookjson.sh"
INPUT=$(cat)
CMD=$(echo "$INPUT" | hookjson command)

# Only fire on git push (not other git commands, not gh pr)
if ! echo "$CMD" | grep -qE '(^|[; &&|])git push'; then
  exit 0
fi

# Check if the schannel flag is already present. If not, remind.
if ! echo "$CMD" | grep -q 'http.sslBackend=schannel'; then
  echo "REMINDER: on Windows, git push may fail without '-c http.sslBackend=schannel'. Consider prepending it."
fi

# Try to check PR state for the current branch. Silent on failure.
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [ -n "$BRANCH" ] && [ "$BRANCH" != "main" ] && [ "$BRANCH" != "master" ]; then
  STATE=$(gh pr list --head "$BRANCH" --state all --json state --jq '.[0].state' 2>/dev/null || echo "")
  if [ "$STATE" = "MERGED" ]; then
    echo "WARNING: branch '$BRANCH' has a MERGED PR. Pushing more commits here violates the one-PR-per-ask rule. Create a new branch instead."
  elif [ "$STATE" = "CLOSED" ]; then
    echo "WARNING: branch '$BRANCH' has a CLOSED (not merged) PR. Reopening intent?"
  fi
fi

exit 0
