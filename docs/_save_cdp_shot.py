#!/usr/bin/env python3
"""Save the newest Page.captureScreenshot CDP JSON response to a PNG path."""
import json, base64, sys
from pathlib import Path

def main():
    out = Path(sys.argv[1])
    logs = Path.home() / ".cursor" / "browser-logs"
    files = sorted(logs.glob("cdp-response-Page.captureScreenshot-*.json"), key=lambda p: p.stat().st_mtime)
    if not files:
        raise SystemExit("no cdp screenshot logs")
    data = json.loads(files[-1].read_text())
    b64 = data.get("data") or (data.get("result") or {}).get("data")
    if not b64:
        raise SystemExit(f"no image data in {files[-1]}")
    out.parent.mkdir(parents=True, exist_ok=True)
    raw = base64.b64decode(b64)
    out.write_bytes(raw)
    # dims
    w = int.from_bytes(raw[16:20], "big")
    h = int.from_bytes(raw[20:24], "big")
    print(f"saved {out} ({w}x{h}) from {files[-1].name}")

if __name__ == "__main__":
    main()
