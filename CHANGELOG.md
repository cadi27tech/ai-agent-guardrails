# Changelog

## 1.0.0, 2026-10-26

First public release: eleven hooks and helpers written after real incidents with AI coding agents between August and October 2026, a `settings.example.json`, and `test.sh`.

Fixed while preparing the release (both covered by `test.sh`):
- `look-before-ocr.sh` recognised only quoted PDF paths. With an unquoted path the pattern also captured the command name, found no such file, and allowed the call.
- `render-all-pages.py` wrote manifests under `~/.claude` while the guard read `$CLAUDE_CONFIG_DIR`, so a custom config directory made the guard block forever.

## Since 1.0.0

- CI: `test.sh` and a syntax check of every hook on each push.
- README: system drawing and a real terminal capture of the guards at work.
