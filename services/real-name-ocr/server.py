"""Private OCR worker. Photos are decoded in memory and never logged or stored."""

import base64
import binascii
import csv
import hmac
import io
import json
import os
import re
import subprocess
import threading
import unicodedata
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from PIL import Image, ImageOps

MAX_BODY = 1_410_000
WORK_SLOTS = threading.BoundedSemaphore(2)

FORMATS = {
    "aadhaar": (r"aadhaar|unique identification authority", r"address|unique identification authority"),
    "voter_id": (r"election commission of india|elector'?s photo identity card", r"address|electoral registration officer"),
    "driving_licence": (r"driving licen[cs]e|driver'?s licen[cs]e", r"address|class of vehicle|licensing authority"),
    "passport": (r"republic of india|passport|issuing authority", r"address|file no|name of father"),
    "pan": (r"income tax department|permanent account number", r"if this card is lost|income tax pan services|return.*card"),
}


def normalize(value):
    value = unicodedata.normalize("NFKC", value).casefold()
    return " ".join(value.split())


def labels(lines, field):
    pattern = re.compile(rf"^(?:{field})(?:\s*[:.-]\s*|\s*$)(.*)$", re.I)
    values = []
    for index, line in enumerate(lines):
        match = pattern.fullmatch(line)
        if match:
            value = match[1] or (lines[index + 1] if index + 1 < len(lines) else "")
            if value and all(unicodedata.category(c)[0] in "LM" or c in " .'-’" for c in value):
                values.append(value)
    return values


def compare(document_type, name, front, back):
    front_marker, back_marker = FORMATS[document_type]
    lines = [line.strip() for line in front.splitlines() if line.strip()]
    candidates = labels(lines, r"(?:full\s+)?name")
    if document_type == "passport":
        surnames = labels(lines, r"surname")
        given = labels(lines, r"given name(?:s|\(s\))?")
        if len(surnames) == 1 and len(given) == 1:
            candidates = [f"{given[0]} {surnames[0]}"]
        elif not surnames and len(given) == 1:
            candidates = given
    if document_type == "aadhaar" and not candidates:
        candidates = [
            lines[index - 1] for index in range(1, len(lines))
            if re.match(r"^(?:dob|date of birth|yob|year of birth)\b", lines[index], re.I)
        ]
    candidates = {normalize(candidate) for candidate in candidates}
    matches = candidates == {normalize(name)}
    recognized = bool(re.search(front_marker, normalize(front)) and re.search(back_marker, normalize(back)))
    return {
        "status": "match" if matches and recognized else
        "mismatch" if recognized and candidates and not matches else "unreadable",
    }


def decode_photo(encoded, mime):
    if not isinstance(encoded, str) or len(encoded) > 699052:
        raise ValueError()
    raw = base64.b64decode(encoded, validate=True)
    if not raw or len(raw) > 524288:
        raise ValueError()
    with Image.open(io.BytesIO(raw), formats=["JPEG", "PNG"]) as photo:
        if (photo.width > 4096 or photo.height > 4096 or
                photo.n_frames != 1 or Image.MIME[photo.format] != mime):
            raise ValueError()
        oriented = ImageOps.exif_transpose(photo)
        oriented.thumbnail((1800, 1800))
        gray = oriented.convert("L")
        clean = Image.new("L", gray.size)
        clean.paste(gray)
        out = io.BytesIO()
        clean.save(out, format="PNG")
        return out.getvalue()


def recognize(png):
    result = subprocess.run(
        ["tesseract", "stdin", "stdout", "-l", "eng", "--psm", "11", "tsv"],
        input=png, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
        timeout=5, check=True, env={"PATH": os.defpath, "OMP_THREAD_LIMIT": "1"},
    )
    lines = {}
    for word in csv.DictReader(io.StringIO(result.stdout.decode("utf-8", errors="replace")), delimiter="\t", quoting=csv.QUOTE_NONE):
        if word["level"] != "5" or not word["text"]:
            continue
        key = tuple(word[col] for col in ("page_num", "block_num", "par_num", "line_num"))
        lines.setdefault(key, []).append((word["text"], float(word["conf"])))
    # Keep a placeholder when a line is unreliable so field labels cannot
    # accidentally pick up the next unrelated name after a low quality line.
    return "\n".join(
        " ".join(text for text, _ in words) if min(conf for _, conf in words) >= 75 else "[unreadable]"
        for words in lines.values()
    )


class Handler(BaseHTTPRequestHandler):
    def setup(self):
        super().setup()
        self.connection.settimeout(8)

    def log_message(self, *_):
        pass

    def send_json(self, status, body):
        payload = json.dumps(body).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        self.send_json(200 if self.path == "/health" else 404, {})

    def do_POST(self):
        if self.path != "/scan":
            self.send_json(404, {})
            return
        if not hmac.compare_digest(
            self.headers.get("Authorization", "").encode(), self.server.authorization
        ):
            self.send_json(401, {})
            return
        if not WORK_SLOTS.acquire(blocking=False):
            self.send_json(503, {})
            return
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size <= MAX_BODY:
                raise ValueError()
            data = json.loads(self.rfile.read(size))
            front = decode_photo(data["front"]["data"], data["front"]["mime"])
            back = decode_photo(data["back"]["data"], data["back"]["mime"])
            if front == back:
                raise ValueError()
            name, document_type = data["name"], data["document_type"]
            if not isinstance(name, str) or not 1 <= len(name.strip()) <= 80 or document_type not in FORMATS:
                raise ValueError()
            self.send_json(200, compare(document_type, name, recognize(front), recognize(back)))
        except (ValueError, KeyError, TypeError, OSError, binascii.Error, Image.DecompressionBombError):
            self.send_json(422, {"status": "invalid_photos"})
        except subprocess.SubprocessError:
            self.send_json(503, {})
        finally:
            WORK_SLOTS.release()


if __name__ == "__main__":
    token = os.environ["REAL_NAME_OCR_TOKEN"]
    if len(token) < 32:
        raise SystemExit("REAL_NAME_OCR_TOKEN must be at least 32 characters")
    with ThreadingHTTPServer(("0.0.0.0", int(os.environ.get("PORT", "8080"))), Handler) as server:
        server.authorization = f"Bearer {token}".encode()
        server.serve_forever()
