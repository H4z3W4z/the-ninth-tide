#!/usr/bin/env python3
"""Tests for tools/web/serve.py:  python3 tools/web/test_serve.py"""
import json
import os
import sys
import tempfile
import threading
import unittest
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import serve  # noqa: E402


class ServeTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        web = os.path.join(self.tmp.name, "web")
        os.makedirs(web)
        with open(os.path.join(web, "index.wasm"), "wb") as f:
            f.write(b"\0asm")
        self.data = os.path.join(self.tmp.name, "data")
        self.srv = serve.make_server(0, web, self.data, "127.0.0.1")
        self.base = f"http://127.0.0.1:{self.srv.server_address[1]}"
        threading.Thread(target=self.srv.serve_forever, daemon=True).start()

    def tearDown(self):
        self.srv.shutdown()
        self.srv.server_close()
        self.tmp.cleanup()

    def call(self, method, path, body=None, raw=None):
        data = raw if raw is not None else (None if body is None else json.dumps(body).encode())
        req = urllib.request.Request(self.base + path, data=data, method=method,
                                     headers={"Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req) as r:
                text = r.read()
                return r.status, (json.loads(text) if text else None), r.headers
        except urllib.error.HTTPError as e:
            text = e.read()
            return e.code, (json.loads(text) if text else None), e.headers

    def test_static_files_and_types(self):
        with urllib.request.urlopen(self.base + "/index.wasm") as r:
            self.assertEqual(r.status, 200)
            self.assertEqual(r.headers["Content-Type"], "application/wasm")

    def test_create_list_and_unique_names(self):
        self.assertEqual(self.call("GET", "/api/profiles")[:2], (200, {"profiles": []}))
        code, p, _ = self.call("POST", "/api/profiles", {"name": "  Mike   Pearson "})
        self.assertEqual(code, 201)
        self.assertEqual((p["id"], p["name"]), ("mike-pearson", "Mike Pearson"))
        code, err, _ = self.call("POST", "/api/profiles", {"name": "mike pearson"})
        self.assertEqual(code, 409)
        self.assertIn("already", err["error"])
        self.assertEqual(self.call("POST", "/api/profiles", {"name": "   "})[0], 400)
        code, p2, _ = self.call("POST", "/api/profiles", {"name": "Ångström!"})
        self.assertEqual((code, p2["id"]), (201, "ngstr-m"))
        code, p3, _ = self.call("POST", "/api/profiles", {"name": "???"})
        self.assertEqual((code, p3["id"]), (201, "player"))
        names = [p["name"] for p in self.call("GET", "/api/profiles")[1]["profiles"]]
        self.assertEqual(names, ["Mike Pearson", "Ångström!", "???"])

    def test_name_is_trimmed_and_capped(self):
        code, p, _ = self.call("POST", "/api/profiles", {"name": "x" * 60 + "\x07"})
        self.assertEqual((code, len(p["name"])), (201, serve.NAME_MAX))

    def test_save_round_trip_and_updated(self):
        pid = self.call("POST", "/api/profiles", {"name": "Ada"})[1]["id"]
        self.assertEqual(self.call("GET", f"/api/profiles/{pid}/save")[:2], (200, {"files": {}, "updated": 0}))
        files = {"progress": '{"room":"R02"}', "settings": "{}"}
        code, r, _ = self.call("PUT", f"/api/profiles/{pid}/save", {"files": files})
        self.assertEqual(code, 200)
        self.assertGreater(r["updated"], 0)
        code, got, _ = self.call("GET", f"/api/profiles/{pid}/save")
        self.assertEqual((code, got["files"]), (200, files))
        listed = self.call("GET", "/api/profiles")[1]["profiles"][0]
        self.assertEqual(listed["updated"], r["updated"])
        # A later write replaces the whole set (a file the game deleted goes away too).
        self.call("PUT", f"/api/profiles/{pid}/save", {"files": {"progress": "{}"}})
        self.assertEqual(self.call("GET", f"/api/profiles/{pid}/save")[1]["files"], {"progress": "{}"})

    def test_put_rejects_bad_files(self):
        pid = self.call("POST", "/api/profiles", {"name": "Ada"})[1]["id"]
        for files in [{}, {"evil": "x"}, {"progress": 3}, {"progress": "x" * (serve.MAX_FILE + 1)}]:
            self.assertEqual(self.call("PUT", f"/api/profiles/{pid}/save", {"files": files})[0], 400, files)
        self.assertEqual(self.call("PUT", f"/api/profiles/{pid}/save", raw=b"not json")[0], 400)
        self.assertEqual(self.call("PUT", f"/api/profiles/{pid}/save", raw=b"[1]")[0], 400)

    def test_put_creates_offline_profile_once(self):
        code, _, _ = self.call("PUT", "/api/profiles/ghost/save", {"files": {"progress": "{}"}})
        self.assertEqual(code, 404)   # no name: not created
        code, _, _ = self.call("PUT", "/api/profiles/ada/save", {"files": {"progress": "{}"}, "name": "Ada"})
        self.assertEqual(code, 200)
        self.assertEqual([p["id"] for p in self.call("GET", "/api/profiles")[1]["profiles"]], ["ada"])
        # Same name under another id (two devices offline): refused, nothing overwritten.
        code, _, _ = self.call("PUT", "/api/profiles/ada-2/save", {"files": {"progress": "{}"}, "name": "ada"})
        self.assertEqual(code, 409)

    def test_delete(self):
        pid = self.call("POST", "/api/profiles", {"name": "Ada"})[1]["id"]
        self.call("PUT", f"/api/profiles/{pid}/save", {"files": {"progress": "{}"}})
        self.assertEqual(self.call("DELETE", f"/api/profiles/{pid}")[0], 204)
        self.assertEqual(self.call("DELETE", f"/api/profiles/{pid}")[0], 404)
        self.assertEqual(self.call("GET", f"/api/profiles/{pid}/save")[0], 404)
        self.assertFalse(os.path.exists(os.path.join(self.data, "saves", pid + ".json")))

    def test_bad_ids_and_paths(self):
        for path in ["/api/profiles/..%2Fetc/save", "/api/profiles/UPPER/save", "/api/nope", "/api/profiles/a/b"]:
            self.assertEqual(self.call("GET", path)[0], 404, path)
        self.assertEqual(self.call("DELETE", "/api/profiles")[0], 404)
        self.assertEqual(self.call("POST", "/api/profiles/ada")[0], 404)

    def test_survives_restart(self):
        pid = self.call("POST", "/api/profiles", {"name": "Ada"})[1]["id"]
        self.call("PUT", f"/api/profiles/{pid}/save", {"files": {"progress": "{\"t\":1}"}})
        store = serve.Store(self.data)
        self.assertEqual(store.get_save(pid)[1]["files"], {"progress": "{\"t\":1}"})


if __name__ == "__main__":
    unittest.main(verbosity=1)
