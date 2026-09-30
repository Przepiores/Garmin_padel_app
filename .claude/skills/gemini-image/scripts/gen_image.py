#!/usr/bin/env python3
"""Generate or edit images with the Gemini API (Nano Banana).

Standard library only, so it runs in Claude Code, in the claude.ai chat
sandbox and on Windows without `pip install`.

Examples:
  python gen_image.py "a padel court at sunset, aerial view" -o court.png
  python gen_image.py "make it night time" -i court.png -o court_night.png
  python gen_image.py "poster" --model gemini-3-pro-image --aspect 16:9 --size 2K
"""
import argparse
import base64
import json
import mimetypes
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

API_URL = "https://generativelanguage.googleapis.com/v1beta/interactions"
DEFAULT_MODEL = "gemini-3.1-flash-image"
MODELS = {
    "lite": "gemini-3.1-flash-lite-image",  # fastest, cheapest, 1K only
    "flash": "gemini-3.1-flash-image",      # default: 512/1K/2K/4K
    "pro": "gemini-3-pro-image",            # best quality, slowest
}
ASPECTS = ["1:1", "3:2", "2:3", "3:4", "4:3", "4:5", "5:4", "9:16", "16:9", "21:9"]
SIZES = ["512", "1K", "2K", "4K"]
EXT = {"image/png": ".png", "image/jpeg": ".jpg", "image/webp": ".webp"}


def load_api_key():
    """GEMINI_API_KEY / GOOGLE_API_KEY env, then an `api_key` file next to the skill."""
    for var in ("GEMINI_API_KEY", "GOOGLE_API_KEY"):
        if os.environ.get(var, "").strip():
            return os.environ[var].strip()
    skill_dir = Path(__file__).resolve().parent.parent
    for path in (skill_dir / "api_key", Path.home() / ".config" / "gemini" / "api_key"):
        if path.is_file():
            key = path.read_text(encoding="utf-8").strip()
            if key:
                return key
    sys.exit(
        "ERROR: no API key. Set GEMINI_API_KEY or put the key in "
        f"{skill_dir / 'api_key'} (one line)."
    )


def image_part(path):
    mime = mimetypes.guess_type(path)[0] or "image/png"
    data = base64.b64encode(Path(path).read_bytes()).decode("ascii")
    return {"type": "image", "mime_type": mime, "data": data}


def find_images(node, found):
    """Collect every image block in the response, whatever the nesting."""
    if isinstance(node, dict):
        if node.get("type") == "image" and node.get("data"):
            found.append((node.get("mime_type") or "image/png", node["data"]))
        inline = node.get("inlineData") or node.get("inline_data")
        if isinstance(inline, dict) and inline.get("data"):
            found.append((inline.get("mimeType") or inline.get("mime_type") or "image/png", inline["data"]))
        for value in node.values():
            find_images(value, found)
    elif isinstance(node, list):
        for value in node:
            find_images(value, found)
    return found


def find_texts(node, found):
    if isinstance(node, dict):
        if node.get("type") == "text" and isinstance(node.get("text"), str):
            found.append(node["text"])
        for key, value in node.items():
            if key != "input":
                find_texts(value, found)
    elif isinstance(node, list):
        for value in node:
            find_texts(value, found)
    return found


def call_api(body, key, timeout):
    request = urllib.request.Request(
        API_URL,
        data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": "application/json", "x-goog-api-key": key},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def explain_http_error(err):
    raw = err.read().decode("utf-8", "replace")
    try:
        payload = json.loads(raw)
        if isinstance(payload, list) and payload:
            payload = payload[0]
        message = payload.get("error", {}).get("message", raw)
    except (ValueError, AttributeError):
        message = raw
    hint = {
        400: "Bad request: check model name, aspect ratio and size.",
        403: "Key rejected or API not enabled for this project. If there is no JSON "
             "body, a network proxy is blocking generativelanguage.googleapis.com.",
        404: "Unknown model name.",
        429: "Quota exhausted. 'limit: 0' means image models are not on the free "
             "tier: enable billing for the key's project in AI Studio.",
    }.get(err.code, "")
    if "API key" in message:
        hint = "The key is wrong or revoked: copy it again from aistudio.google.com/apikey."
    return f"HTTP {err.code}: {message.strip()[:600]}\nHint: {hint}"


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("prompt", help="What to generate or how to edit the input image(s).")
    parser.add_argument("-i", "--image", action="append", default=[],
                        help="Reference / input image to edit (repeatable, up to 14).")
    parser.add_argument("-o", "--output", default="generated.png",
                        help="Output path. Extension is fixed to match the returned type.")
    parser.add_argument("-m", "--model", default=DEFAULT_MODEL,
                        help=f"Model id or alias ({', '.join(MODELS)}). Default: {DEFAULT_MODEL}.")
    parser.add_argument("-a", "--aspect", choices=ASPECTS, help="Aspect ratio (default: model decides).")
    parser.add_argument("-s", "--size", choices=SIZES, help="Resolution (lite supports 1K only).")
    parser.add_argument("--previous", help="previous_interaction_id to continue a multi-turn edit.")
    parser.add_argument("--timeout", type=int, default=180)
    args = parser.parse_args()

    model = MODELS.get(args.model, args.model)
    body = {"model": model}
    if args.image:
        body["input"] = [{"type": "text", "text": args.prompt}] + [image_part(p) for p in args.image]
    else:
        body["input"] = args.prompt
    if args.previous:
        body["previous_interaction_id"] = args.previous
    if args.aspect or args.size:
        body["response_format"] = {"type": "image"}
        if args.aspect:
            body["response_format"]["aspect_ratio"] = args.aspect
        if args.size:
            body["response_format"]["image_size"] = args.size

    key = load_api_key()
    started = time.time()
    try:
        result = call_api(body, key, args.timeout)
    except urllib.error.HTTPError as err:
        sys.exit("ERROR " + explain_http_error(err))
    except urllib.error.URLError as err:
        sys.exit(f"ERROR network: {err.reason}. Is generativelanguage.googleapis.com "
                 "allowed in this environment's network settings?")

    images = find_images(result.get("outputs", result), [])
    texts = find_texts(result.get("outputs", []), [])
    if not images:
        print(json.dumps(result, indent=2)[:2000], file=sys.stderr)
        sys.exit("ERROR: response contained no image (blocked by safety filter or text-only reply).")

    # The last image is the final one; earlier ones can be interim "thought" images.
    mime, data = images[-1]
    out = Path(args.output)
    out = out.with_suffix(EXT.get(mime, out.suffix or ".png"))
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(base64.b64decode(data))

    print(json.dumps({
        "file": str(out.resolve()),
        "mime_type": mime,
        "bytes": out.stat().st_size,
        "model": model,
        "interaction_id": result.get("id"),
        "seconds": round(time.time() - started, 1),
        "text": " ".join(t.strip() for t in texts if t.strip())[:500] or None,
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
