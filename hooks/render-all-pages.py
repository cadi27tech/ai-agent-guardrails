#!/usr/bin/env python
"""Render every page of a PDF to PNG under the many-image size cap, and write a
manifest the look-before-ocr hook checks against the looked-at log.

Usage: python render-all-pages.py <file.pdf> [outdir]

The long edge is capped at 1400px. Anything over 2000px per side permanently
poisons a session, because every later turn replays the image.
"""
import hashlib
import os
import sys

import fitz

CAP = 1400
# Must match the directory the look-before-ocr guard reads. An earlier version
# hard-coded ~/.claude here while the guard honoured CLAUDE_CONFIG_DIR,
# so on a machine with a custom config dir the guard never found a manifest.
CONFIG = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.join(os.path.expanduser("~"), ".claude")


def main():
    pdf = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(
        CONFIG, "renders",
        os.path.splitext(os.path.basename(pdf))[0])
    os.makedirs(out, exist_ok=True)

    with open(pdf, "rb") as fh:
        md5 = hashlib.md5(fh.read()).hexdigest()

    doc = fitz.open(pdf)
    paths = []
    text_pages = 0
    for i, page in enumerate(doc):
        if page.get_text().strip():
            text_pages += 1
        zoom = CAP / max(page.rect.width, page.rect.height)
        path = os.path.join(out, "p%03d.png" % (i + 1))
        page.get_pixmap(matrix=fitz.Matrix(zoom, zoom)).save(path)
        paths.append(path.replace("\\", "/").lower())

    mandir = os.path.join(CONFIG, "render-manifests")
    os.makedirs(mandir, exist_ok=True)
    # newline="" keeps LF endings on Windows. With CRLF the guard's grep -qxF
    # can never match a log line written by bash, so it would report every page
    # unlooked forever.
    with open(os.path.join(mandir, md5 + ".manifest"), "w", newline="") as fh:
        fh.write("\n".join(paths) + "\n")

    print("pages: %d" % len(paths))
    print("pages with a text layer: %d" % text_pages)
    if text_pages == 0:
        print("NO TEXT LAYER AT ALL. Extraction will return empty strings. "
              "That silence is not absence, it is a scan. Read the images.")
    print("renders: %s" % out)


if __name__ == "__main__":
    main()
