#!/usr/bin/env python3
"""Home-network server for The Ninth Tide web build: the game's files plus a tiny profile
and save API (game/lobby/save_sync.gd is the client).

    GET    /api/profiles               -> 200 {"profiles": [{id, name, updated}]}
    POST   /api/profiles  {name}       -> 201 {id, name, updated} | 400/409 {error}
    DELETE /api/profiles/<id>          -> 204 | 404
    GET    /api/profiles/<id>/save     -> 200 {files: {key: text}, updated} | 404
    PUT    /api/profiles/<id>/save  {files, name?}
                                       -> 200 {updated} | 400/404/409 {error}
       (creates the profile if it is new and a name is given: a profile made offline)

No accounts or passwords by design: it is reachable only from the home LAN (the host
firewall allows the port from 192.168.1.0/24 only). Saves are last-write-wins.

Stdlib only. Env: NT_WEB_ROOT, NT_DATA_DIR, NT_PORT, NT_TLS_CERT, NT_TLS_KEY (or a systemd
credential named tls.key). Without a cert it serves plain HTTP (tests, localhost).
"""
import functools
import gzip
import http.server
import shutil
import json
import os
import re
import ssl
import tempfile
import threading
import time

WEB_ROOT = os.environ.get("NT_WEB_ROOT", "/srv/ninth-tide/web")
DATA_DIR = os.environ.get("NT_DATA_DIR") or os.environ.get("STATE_DIRECTORY") or "/var/lib/ninth-tide"
PORT = int(os.environ.get("NT_PORT", "8099"))

ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,39}$")
FILE_KEYS = {"progress", "settings", "prev", "checkpoint"}
NAME_MAX = 24
MAX_BODY = 4 * 1024 * 1024       # whole request
MAX_FILE = 2 * 1024 * 1024       # one save file
MAX_PROFILES = 64
# Served gzipped (precompressed beside the original as <name>.gz) when the browser accepts it.
GZIP_EXTS = (".wasm", ".js", ".html", ".pck")

_lock = threading.Lock()


def clean_name(s):
    s = "".join(ch for ch in str(s).strip() if ch.isprintable())
    s = re.sub(r"\s+", " ", s)
    return s[:NAME_MAX].strip()


def make_id(name, taken):
    slug = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")[:32] or "player"
    pid, n = slug, 2
    while pid in taken:
        pid, n = f"{slug}-{n}", n + 1
    return pid


class Store:
    """profiles.json holds the index; saves/<id>.json holds each profile's files."""

    def __init__(self, root):
        self.root = root
        os.makedirs(os.path.join(root, "saves"), exist_ok=True)

    def _write(self, path, obj):
        fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".tmp-")
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(obj, f)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, path)

    def _index_path(self):
        return os.path.join(self.root, "profiles.json")

    def _save_path(self, pid):
        return os.path.join(self.root, "saves", pid + ".json")

    def profiles(self):
        try:
            with open(self._index_path(), encoding="utf-8") as f:
                data = json.load(f)
            return [p for p in data.get("profiles", []) if ID_RE.match(str(p.get("id", "")))]
        except (FileNotFoundError, ValueError):
            return []

    def _set_profiles(self, ps):
        self._write(self._index_path(), {"profiles": ps})

    def create(self, name, pid=None):
        name = clean_name(name)
        if not name:
            return 400, {"error": "Write a name first."}
        ps = self.profiles()
        if len(ps) >= MAX_PROFILES:
            return 409, {"error": "The log book is full."}
        for p in ps:
            if p["name"].casefold() == name.casefold():
                return 409, {"error": f"{p['name']} already keeps a watch here."}
        pid = pid or make_id(name, {p["id"] for p in ps})
        if not ID_RE.match(pid) or any(p["id"] == pid for p in ps):
            return 409, {"error": "That player id is taken."}
        p = {"id": pid, "name": name, "updated": 0}
        ps.append(p)
        self._set_profiles(ps)
        return 201, p

    def remove(self, pid):
        ps = self.profiles()
        if not any(p["id"] == pid for p in ps):
            return 404, {"error": "No such player."}
        self._set_profiles([p for p in ps if p["id"] != pid])
        try:
            os.remove(self._save_path(pid))
        except FileNotFoundError:
            pass
        return 204, None

    def get_save(self, pid):
        p = next((p for p in self.profiles() if p["id"] == pid), None)
        if p is None:
            return 404, {"error": "No such player."}
        try:
            with open(self._save_path(pid), encoding="utf-8") as f:
                files = json.load(f).get("files", {})
        except (FileNotFoundError, ValueError):
            files = {}
        return 200, {"files": files, "updated": p.get("updated", 0)}

    def put_save(self, pid, body):
        files = body.get("files")
        if not isinstance(files, dict) or not files:
            return 400, {"error": "files must be a non-empty object."}
        for k, v in files.items():
            if k not in FILE_KEYS or not isinstance(v, str) or len(v) > MAX_FILE:
                return 400, {"error": f"bad file {k!r}"}
        ps = self.profiles()
        p = next((p for p in ps if p["id"] == pid), None)
        if p is None:
            name = clean_name(body.get("name", ""))
            if not name:
                return 404, {"error": "No such player."}
            code, made = self.create(name, pid)
            if code != 201:
                return code, made
            ps = self.profiles()
            p = next(p for p in ps if p["id"] == pid)
        now = int(time.time())
        self._write(self._save_path(pid), {"files": files})
        p["updated"] = now
        self._set_profiles(ps)
        return 200, {"updated": now}


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map,
                      ".wasm": "application/wasm", ".pck": "application/octet-stream",
                      ".js": "text/javascript"}
    store = None

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def log_message(self, fmt, *args):
        # One line per request to stderr (the systemd journal): enough to see how far a
        # device's load got. LAN only; no request bodies are logged.
        ua = self.headers.get("User-Agent", "-") if hasattr(self, "headers") and self.headers else "-"
        print(f"{self.client_address[0]} {fmt % args} ua={ua[:120]!r}", flush=True)

    def _send_gz(self):
        """Serves <file>.gz for a GET of <file> when the browser accepts gzip. True if sent."""
        path = self.translate_path(self.path.split("?", 1)[0])
        if not path.endswith(GZIP_EXTS) or "gzip" not in self.headers.get("Accept-Encoding", ""):
            return False
        gz = path + ".gz"
        try:
            if os.path.getmtime(gz) < os.path.getmtime(path):
                return False   # stale: the original changed after it was compressed
            f = open(gz, "rb")
        except OSError:
            return False
        with f:
            size = os.fstat(f.fileno()).st_size
            self.send_response(200)
            self.send_header("Content-Type", self.guess_type(path))
            self.send_header("Content-Encoding", "gzip")
            self.send_header("Vary", "Accept-Encoding")
            self.send_header("Content-Length", str(size))
            self.end_headers()
            if self.command != "HEAD":
                shutil.copyfileobj(f, self.wfile)
        return True

    def _json(self, code, obj):
        body = b"" if obj is None else json.dumps(obj).encode()
        self.send_response(code)
        if obj is not None:
            self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        if n <= 0 or n > MAX_BODY:
            return None
        try:
            obj = json.loads(self.rfile.read(n))
        except ValueError:
            return None
        return obj if isinstance(obj, dict) else None

    def _route(self):
        """('list'|'one'|'save', id) for /api paths, or None."""
        path = self.path.split("?", 1)[0].rstrip("/")
        if path == "/api/profiles":
            return "list", None
        m = re.match(r"^/api/profiles/([^/]+)(/save)?$", path)
        if m and ID_RE.match(m.group(1)):
            return ("save" if m.group(2) else "one"), m.group(1)
        if path.startswith("/api/"):
            return "bad", None
        return None

    def do_GET(self):
        r = self._route()
        if r is None:
            if self._send_gz():
                return
            return super().do_GET()
        kind, pid = r
        with _lock:
            if kind == "list":
                return self._json(200, {"profiles": self.store.profiles()})
            if kind == "save":
                return self._json(*self.store.get_save(pid))
        self._json(404, {"error": "not found"})

    def do_POST(self):
        if self.path.split("?", 1)[0] == "/api/clientlog":
            # Load diagnostics from tools/web/diag.js: logged, never stored.
            n = int(self.headers.get("Content-Length") or 0)
            if 0 < n <= 4096:
                print(f"{self.client_address[0]} CLIENTLOG {self.rfile.read(n).decode('utf-8', 'replace')}", flush=True)
            return self._json(204, None)
        r = self._route()
        if r != ("list", None):
            return self._json(404, {"error": "not found"})
        body = self._body()
        if body is None:
            return self._json(400, {"error": "expected a JSON object"})
        with _lock:
            self._json(*self.store.create(body.get("name", "")))

    def do_PUT(self):
        r = self._route()
        if r is None or r[0] != "save":
            return self._json(404, {"error": "not found"})
        body = self._body()
        if body is None:
            return self._json(400, {"error": "expected a JSON object"})
        with _lock:
            self._json(*self.store.put_save(r[1], body))

    def do_DELETE(self):
        r = self._route()
        if r is None or r[0] != "one":
            return self._json(404, {"error": "not found"})
        with _lock:
            self._json(*self.store.remove(r[1]))


def precompress(web_root):
    """Writes <file>.gz beside each servable file that gzip shrinks by 10% or more."""
    for name in os.listdir(web_root):
        path = os.path.join(web_root, name)
        if not name.endswith(GZIP_EXTS) or not os.path.isfile(path):
            continue
        gz = path + ".gz"
        if os.path.exists(gz) and os.path.getmtime(gz) >= os.path.getmtime(path):
            continue
        with open(path, "rb") as f:
            data = f.read()
        packed = gzip.compress(data, compresslevel=9, mtime=0)
        if len(packed) <= 0.9 * len(data):
            with open(gz + ".tmp", "wb") as f:
                f.write(packed)
            os.replace(gz + ".tmp", gz)
        elif os.path.exists(gz):
            os.remove(gz)


def make_server(port=PORT, web_root=WEB_ROOT, data_dir=DATA_DIR, host="0.0.0.0"):
    handler = type("H", (Handler,), {"store": Store(data_dir)})
    return http.server.ThreadingHTTPServer((host, port), functools.partial(handler, directory=web_root))


def main():
    srv = make_server()
    cert = os.environ.get("NT_TLS_CERT", "/srv/ninth-tide/tls.crt")
    key = os.environ.get("NT_TLS_KEY") or os.path.join(os.environ.get("CREDENTIALS_DIRECTORY", "/nonexistent"), "tls.key")
    if os.path.exists(cert) and os.path.exists(key):
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ctx.load_cert_chain(cert, key)
        srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
    srv.serve_forever()


if __name__ == "__main__":
    main()
