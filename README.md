# ai-agent-guardrails

Claude Code hooks that turn "the agent said it did X" into "the harness checked X". Each one exists because something went wrong in real work with AI coding agents, and the comment at the top of every script records what.

The design rule behind all of them: **a guard that cannot read its input must fail loud, not wave the call through.** A blocking hook that silently exits 0 is worse than no hook, because it looks like enforcement.

## The hooks

| Hook | Event | Blocks? | What it does |
|---|---|---|---|
| `_hookjson.sh` | helper | - | Shared JSON reader for every bash hook. Uses Python, sets `HOOKJSON_OK` so blocking hooks can refuse when parsing is impossible. |
| `look-before-ocr.sh` | PreToolUse (Bash) | yes | Refuses text extraction from a PDF (`pdftotext`, `pdfplumber`, `PyPDF`, `tesseract`, ...) until every page has been rendered and actually shown to the model. |
| `render-all-pages.py` | manual | - | Renders every PDF page to PNG under 1400 px and writes the manifest that `look-before-ocr.sh` checks. Reports pages with no text layer. |
| `looked-at-log.sh` | PostToolUse (Read) | no | Logs every image path that was really put in front of the model. This log, not the model's claim, is the evidence. |
| `no-em-dash.sh` | PreToolUse (Write/Edit) | yes | Blocks writes containing em-dash or en-dash characters. A house style rule, enforced instead of requested. |
| `first-person-voice-warn.sh` | PreToolUse (Write/Edit) | warn | Flags outreach-style first-person phrasing ("I hope this finds you well") in .md/.html/.txt so drafted copy is not shipped in the user's voice by accident. |
| `git-push-guard.sh` | PreToolUse (Bash) | warn | On `git push`: warns when the branch's PR is already merged or closed (one PR per ask), and reminds about a Windows TLS flag. |
| `image-size-guard.ps1` | PreToolUse (Read, browser screenshot) | yes | Blocks full-page browser screenshots and downscales oversized images before they are read. |
| `precompact-state.sh` | PreCompact | no | At the instant of context compaction, freezes git state for every repo under cwd plus the last files touched and commands run. |
| `precompact-transcript.js` | helper | - | Parses the session transcript (JSONL) for `precompact-state.sh`. |
| `session-start-context.sh` | SessionStart | no | Prints a bounded "where were we" report; after a compaction it replays the frozen state first. |

## The incidents behind them

**Every guard enforced nothing for three days.** The first versions parsed hook input with `jq`, which was not installed. Each hook fell through to exit 0, so from 17 to 20 Aug 2026 nothing was blocked and nothing said so. Fix: `_hookjson.sh` (Python, which was present) and a `HOOKJSON_OK` flag that blocking hooks check before deciding anything.

**Conclusions drawn from documents nobody opened.** On 19 Aug 2026 four attached PDFs were reasoned about from extracted text without being looked at. Six conclusions were wrong, and three of the six findings were handwritten in pen, which no text extraction can see. The next day, an earlier session's claim that a 57-page pack had been "read page by page" was reused as proof of coverage. A claim is not evidence. Fix: `render-all-pages.py` + `looked-at-log.sh` + `look-before-ocr.sh`, which make "looked at every page" mechanical. Scanned PDFs with no text layer return empty strings that read as absence; the renderer says so explicitly.

**A CRLF manifest that could never match.** On Windows, Python writes text files with CRLF line endings by default, and the guard's exact-line match against a bash-written log can then never succeed: every page reads as unlooked forever. Fix: `newline=""` on write and stripping `\r` on read.

**One oversized image poisons a session.** Images over 2000 px per side break many-image requests, and every later turn replays them. A few full-page screenshots were enough. Fix: `image-size-guard.ps1` blocks `fullPage` captures and points the agent at a downscaled copy.

**Lost position after compaction.** The compaction summary keeps the conversation gist but drops which files were mid-edit. The first `precompact-state.sh` reported only the first git repo under cwd, so with three sibling repos it froze a stale branch while the active one went unrecorded. The first transcript parser used `grep` and printed eight lines of `python3 \` because escaped quotes truncate a regex match. Fix: report every repo, and parse the JSONL with Node.

**Commits pushed to an already-merged branch.** The working rule is one PR per ask. An agent that keeps pushing to a branch whose PR has already merged is shipping work that will never reach main. Fix: `git-push-guard.sh` checks the PR state before every push and says so.

**Fixes found while preparing this repo** (both are in the published versions and covered by `test.sh`):
- `look-before-ocr.sh` only recognised quoted PDF paths. With an unquoted path the pattern also captured the command name, found no such file, and allowed the call.
- `render-all-pages.py` wrote manifests under `~/.claude` while the guard read `$CLAUDE_CONFIG_DIR`, so a custom config directory made the guard block forever.

## Install

1. Copy `hooks/` to `~/.claude/hooks/` (or `$CLAUDE_CONFIG_DIR/hooks/`).
2. Merge the `hooks` block from `settings.example.json` into `~/.claude/settings.json`. Fix the `image-size-guard.ps1` path, or drop it on macOS/Linux.
3. Requirements: bash, Python 3 (PyMuPDF for `render-all-pages.py`), Node for the compaction parser, `gh` for the push guard. `precompact-state.sh` and `session-start-context.sh` read `.remember/` files when a project keeps them and skip them otherwise.
4. Run `bash test.sh`. Every line should read `ok`.

Edit the phrase list in `first-person-voice-warn.sh` to suit your own writing. It is a warning, not a block, because technical prose uses "I" and "we" legitimately.

## License

MIT
