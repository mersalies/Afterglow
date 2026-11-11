#!/usr/bin/env python3
"""Spotify sign-in for Afterglow (Authorization Code + PKCE, no client secret).

  spotify-auth.py login CLIENT_ID   open the browser, wait for the redirect, store tokens
  spotify-auth.py token             print a valid access token (refreshing it if needed)
  spotify-auth.py logout            forget the stored tokens

Tokens live in ~/.config/afterglow/spotify.json (mode 600).
Exit codes: 0 ok, 2 not signed in, 1 any other failure (message on stderr).
"""

import base64
import hashlib
import http.server
import json
import os
import secrets
import subprocess
import sys
import time
import urllib.parse
import urllib.request

REDIRECT_PORT = 8898
REDIRECT_URI = f"http://127.0.0.1:{REDIRECT_PORT}/callback"
SCOPES = " ".join([
    "user-read-playback-state",
    "user-modify-playback-state",
    "user-read-currently-playing",
    "playlist-read-private",
    "playlist-read-collaborative",
    "user-library-read",
    "user-library-modify",
])
CONFIG_DIR = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "afterglow")
STORE = os.path.join(CONFIG_DIR, "spotify.json")

PAGE = """<!doctype html><meta charset="utf-8"><title>Afterglow</title>
<body style="background:#0d0b14;color:#fff;font:18px system-ui;display:grid;place-items:center;height:100vh;margin:0">
<div style="text-align:center"><h1 style="font-weight:600">{title}</h1><p style="opacity:.7">{text}</p></div>"""


def fail(msg, code=1):
    print(msg, file=sys.stderr)
    sys.exit(code)


def post_token(params):
    data = urllib.parse.urlencode(params).encode()
    req = urllib.request.Request("https://accounts.spotify.com/api/token", data=data,
                                 headers={"Content-Type": "application/x-www-form-urlencoded"})
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        fail(f"Spotify отказал: {e.code} {e.read().decode(errors='replace')}")
    except OSError as e:
        fail(f"Нет связи со Spotify: {e}")


def save(client_id, tok, old_refresh=None):
    os.makedirs(CONFIG_DIR, exist_ok=True)
    data = {
        "client_id": client_id,
        "access_token": tok["access_token"],
        "refresh_token": tok.get("refresh_token") or old_refresh,
        "expires_at": int(time.time()) + int(tok.get("expires_in", 3600)) - 60,
    }
    fd = os.open(STORE, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(data, f)
    return data


def login(client_id):
    verifier = secrets.token_urlsafe(64)[:96]
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
    state = secrets.token_urlsafe(16)
    url = "https://accounts.spotify.com/authorize?" + urllib.parse.urlencode({
        "client_id": client_id,
        "response_type": "code",
        "redirect_uri": REDIRECT_URI,
        "code_challenge_method": "S256",
        "code_challenge": challenge,
        "scope": SCOPES,
        "state": state,
    })
    result = {}

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            ok = q.get("state", [""])[0] == state and "code" in q
            if ok:
                result["code"] = q["code"][0]
            else:
                result["error"] = q.get("error", ["неверный ответ"])[0]
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            page = PAGE.format(title="Spotify подключён" if ok else "Не получилось",
                               text="Можно закрыть вкладку и вернуться в Afterglow." if ok
                               else "Spotify ответил: " + result["error"])
            self.wfile.write(page.encode())

        def log_message(self, *args):
            pass

    try:
        server = http.server.HTTPServer(("127.0.0.1", REDIRECT_PORT), Handler)
    except OSError:
        fail(f"Порт {REDIRECT_PORT} занят, закрой то, что его держит, и попробуй снова")
    server.timeout = 180
    subprocess.Popen(["xdg-open", url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    deadline = time.time() + 180
    while not result and time.time() < deadline:
        server.handle_request()
    server.server_close()

    if "code" not in result:
        fail("Вход отменён: " + result.get("error", "время ожидания вышло"))
    tok = post_token({
        "grant_type": "authorization_code",
        "code": result["code"],
        "redirect_uri": REDIRECT_URI,
        "client_id": client_id,
        "code_verifier": verifier,
    })
    save(client_id, tok)
    print("ok")


def token():
    try:
        with open(STORE) as f:
            data = json.load(f)
    except (OSError, ValueError):
        fail("не выполнен вход", 2)
    if data["expires_at"] <= time.time():
        if not data.get("refresh_token"):
            fail("не выполнен вход", 2)
        tok = post_token({
            "grant_type": "refresh_token",
            "refresh_token": data["refresh_token"],
            "client_id": data["client_id"],
        })
        data = save(data["client_id"], tok, data["refresh_token"])
    print(data["access_token"])


def logout():
    try:
        os.remove(STORE)
    except FileNotFoundError:
        pass
    print("ok")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "login" and len(sys.argv) == 3 and sys.argv[2].strip():
        login(sys.argv[2].strip())
    elif cmd == "token":
        token()
    elif cmd == "logout":
        logout()
    else:
        fail(__doc__)
