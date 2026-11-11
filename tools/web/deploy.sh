#!/usr/bin/env bash
# Deploys a Godot web export to Beast (LAN-only server; see tools/web/serve.py).
#   tools/web/deploy.sh <export-dir>        e.g. the folder holding index.html/.wasm/.pck
# Post-export fixes applied to a copy, never to the export itself:
#  1. Emscripten's user-agent version gate is disabled. It throws on any UA that claims
#     Safari < 15.2, which iPad Chrome's "Request desktop site" mode does (it reports
#     "Version/11.1.1" on a current iPadOS). Godot's own feature check still runs.
#  2. tools/web/diag.js is injected, reporting load errors/stalls to the server log.
#  3. Text and wasm are precompressed (serve.py sends .gz when the browser accepts gzip).
set -euo pipefail
SRC=${1:?export dir}
HOST=${NT_HOST:-root@100.81.188.18}
HERE=$(cd "$(dirname "$0")" && pwd)
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cp -a "$SRC"/. "$STAGE"/
rm -f "$STAGE"/*.gz
python3 - "$STAGE/index.js" <<'PY'
import re, sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
n = 0
for browser in ("Safari", "Firefox", "Chrome"):
    s, k = re.subn(r"if\(current%sVersion<" % browser, "if(false&&current%sVersion<" % browser, s)
    n += k
if n != 3:
    sys.exit(f"UA gate patch: expected 3 checks, patched {n}; emscripten changed, inspect index.js")
open(p, "w", encoding="utf-8").write(s)
print("UA version gate disabled (3 checks)")
PY
cp "$HERE/diag.js" "$STAGE/diag.js"
grep -q 'diag.js' "$STAGE/index.html" || sed -i 's#<head>#<head><script src="diag.js"></script>#' "$STAGE/index.html"
python3 -c "import sys; sys.path.insert(0, '$HERE'); import serve; serve.precompress('$STAGE')"
ssh -o BatchMode=yes "$HOST" 'rm -rf /srv/ninth-tide/web.prev && cp -a /srv/ninth-tide/web /srv/ninth-tide/web.prev'
rsync -az --delete "$STAGE"/ "$HOST":/srv/ninth-tide/web/
scp -q "$HERE/serve.py" "$HOST":/srv/ninth-tide/serve.py
ssh "$HOST" 'chmod -R a+rX /srv/ninth-tide/web /srv/ninth-tide/serve.py && systemctl restart ninth-tide-web && systemctl is-active ninth-tide-web'
echo "deployed; previous build kept at /srv/ninth-tide/web.prev"
