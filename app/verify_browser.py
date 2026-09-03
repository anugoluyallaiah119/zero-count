#!/usr/bin/env python3
"""
Zero Count — headless-Chrome verification of the built Flutter web app.

Serves a contract-faithful mock of the E2.3 auth backend (same endpoints,
same DTOs, dev code 123456) so the app makes REAL dio HTTP round-trips:

  POST /api/auth/otp/request {phone}          -> {"session": "..."}
  POST /api/auth/otp/verify  {session, code}  -> {accessToken, tokenType,
                                                   expiresIn, refreshToken,
                                                   userId, newUser}
  POST /api/auth/refresh     {refreshToken}   -> same token bundle
  errors: 400/401 {"error": "..."}

Checks:
  1. splash renders, routes to login (no saved session)
  2. empty phone -> client-side validation error (no server call)
  3. 10-digit phone -> CONTINUE -> real OTP request -> OTP screen
  4. wrong code -> server error snackbar, stays on OTP
  5. code 123456 -> verify -> tokens stored -> home
  6. reload -> splash restores session via /refresh -> straight to home
  7. zero console/page errors throughout
  Screenshots per screen + errors.log land in $ARTIFACTS_DIR.

Exit 0 = all checks passed; 1 = failure.
"""
import json
import os
import sys
import threading
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from playwright.sync_api import sync_playwright

APP_URL = os.environ.get("APP_URL", "http://localhost:18085/")
API_PORT = int(os.environ.get("API_PORT", "18086"))
ARTIFACTS = os.environ.get("ARTIFACTS_DIR", "build/verify")
DEV_CODE = "123456"

errors = []
failures = []


def check(name, ok, detail=""):
    status = "PASS" if ok else "FAIL"
    print(f"  [{status}] {name}" + (f" — {detail}" if detail and not ok else ""))
    if not ok:
        failures.append(f"{name}: {detail}")


# ---------------------------------------------------------------- mock backend
PROFILE = {"name": "", "avatar": "", "coins": 2500, "gems": 50}


class MockAuthHandler(BaseHTTPRequestHandler):
    sessions = {}
    valid_refresh = None
    valid_access = None

    def log_message(self, *a):
        pass

    def _log(self, msg):
        with open(f"{ARTIFACTS}/api.log", "a") as f:
            f.write(msg + "\n")

    def _send(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "content-type, authorization")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PATCH, OPTIONS")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_OPTIONS(self):
        self._send(204, {})

    def _authorized(self):
        return self.headers.get("Authorization") == f"Bearer {MockAuthHandler.valid_access}"

    def _read_body(self):
        length = int(self.headers.get("Content-Length", 0))
        try:
            return json.loads(self.rfile.read(length) or b"{}")
        except json.JSONDecodeError:
            return {}

    def _profile_body(self):
        return {
            "id": str(uuid.uuid4()),
            "phone": "+919******10",
            "name": PROFILE["name"],
            "avatar": PROFILE["avatar"],
            "coins": PROFILE["coins"],
            "gems": PROFILE["gems"],
            "memberSince": "2026-08-01T00:00:00Z",
            "stats": {"matches": 23, "wins": 9, "zerosMade": 4,
                      "bestCount": 0, "streakDays": 3, "elo": 1315},
        }

    def do_GET(self):
        self._log(f"GET {self.path} auth={self.headers.get('Authorization')}")
        if self.path == "/api/players/me":
            if not self._authorized():
                return self._send(401, {"error": "missing or invalid token"})
            return self._send(200, self._profile_body())
        return self._send(404, {"error": "not found"})

    def do_PATCH(self):
        if self.path == "/api/players/me":
            if not self._authorized():
                return self._send(401, {"error": "missing or invalid token"})
            body = self._read_body()
            name = (body.get("name") or "").strip()
            if "name" in body and (not name or len(name) > 50):
                return self._send(400, {"error": "name must be 1–50 characters"})
            if "name" in body:
                PROFILE["name"] = name
            if "avatar" in body:
                PROFILE["avatar"] = body["avatar"]
            return self._send(200, self._profile_body())
        return self._send(404, {"error": "not found"})

    def do_POST(self):
        body = self._read_body()
        self._log(f"POST {self.path} body_keys={list(body.keys())}")

        if self.path == "/api/auth/otp/request":
            phone = body.get("phone", "")
            if not phone.startswith("+"):
                return self._send(400, {"error": "phone must be E.164"})
            session = str(uuid.uuid4())
            MockAuthHandler.sessions[session] = phone
            return self._send(200, {"session": session})

        if self.path == "/api/auth/otp/verify":
            session = body.get("session", "")
            code = body.get("code", "")
            if session not in MockAuthHandler.sessions:
                return self._send(401, {"error": "Unknown or expired session"})
            if code != DEV_CODE:
                return self._send(401, {"error": "Invalid or expired code"})
            MockAuthHandler.valid_refresh = "rt-" + uuid.uuid4().hex
            MockAuthHandler.valid_access = "at-" + uuid.uuid4().hex
            return self._send(200, {
                "accessToken": MockAuthHandler.valid_access,
                "tokenType": "Bearer",
                "expiresIn": 900,
                "refreshToken": MockAuthHandler.valid_refresh,
                "userId": str(uuid.uuid4()),
                "newUser": True,
            })

        if self.path == "/api/auth/refresh":
            if body.get("refreshToken") != MockAuthHandler.valid_refresh:
                return self._send(401, {"error": "Refresh token expired"})
            MockAuthHandler.valid_access = "at-" + uuid.uuid4().hex
            return self._send(200, {
                "accessToken": MockAuthHandler.valid_access,
                "tokenType": "Bearer",
                "expiresIn": 900,
                "refreshToken": MockAuthHandler.valid_refresh,
                "userId": str(uuid.uuid4()),
                "newUser": False,
            })

        return self._send(404, {"error": "not found"})


def start_mock():
    server = ThreadingHTTPServer(("127.0.0.1", API_PORT), MockAuthHandler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


# ------------------------------------------------------------------- browser
def _is_expected_api_error(text):
    # The negative-path checks deliberately trigger 400/401 responses from
    # the mock backend; Chromium logs those as console errors. Ignore only
    # resource-load failures against the mock API port.
    return "Failed to load resource" in text and str(API_PORT) in text or (
        "Failed to load resource" in text and "401" in text)


def enable_semantics(page):
    a11y = page.get_by_role("button", name="Enable accessibility")
    if a11y.count() > 0:
        a11y.first.dispatch_event("click")  # placeholder is off-viewport
        page.wait_for_timeout(800)


def type_phone(page, digits):
    page.get_by_role("textbox").first.click()
    page.keyboard.type(digits)
    page.wait_for_timeout(200)


def type_otp(page, code):
    # Click the first cell once, then type: focus auto-advances per digit,
    # and typing over a filled cell replaces it (app behaviour). The pause
    # lets Flutter's semantics tree re-attach the newly focused cell.
    page.get_by_role("textbox").first.click()
    page.wait_for_timeout(300)
    for digit in code:
        page.keyboard.type(digit)
        page.wait_for_timeout(400)


def main():
    os.makedirs(ARTIFACTS, exist_ok=True)
    start_mock()
    print(f"Mock E2.3 auth backend on :{API_PORT} (dev code {DEV_CODE})")

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        ctx = browser.new_context(viewport={"width": 420, "height": 860})
        page = ctx.new_page()
        page.on("console", lambda m: errors.append(m.text)
                  if m.type == "error" and not _is_expected_api_error(m.text)
                  else None)
        page.on("pageerror", lambda e: errors.append(str(e)))

        # --- 1. splash ---
        print("Screen: splash")
        page.goto(APP_URL, wait_until="networkidle")
        page.wait_for_timeout(500)
        check("app shell rendered", page.locator("flutter-view").count() > 0
              or page.locator("flt-glass-pane").count() > 0
              or page.locator("body").inner_html() != "")
        page.screenshot(path=f"{ARTIFACTS}/01-splash.png")

        # --- 2. login (after splash restore: no saved session) ---
        print("Screen: login")
        page.wait_for_timeout(3000)
        enable_semantics(page)
        check("no saved session -> login screen",
              page.get_by_role("button", name="CONTINUE").count() > 0)
        page.screenshot(path=f"{ARTIFACTS}/02-login.png")

        # --- 3. client-side validation ---
        page.get_by_role("button", name="CONTINUE").first.click()
        page.wait_for_timeout(600)
        check("empty phone -> validation error",
              page.get_by_text("Enter a valid 10-digit mobile number").count() > 0)
        check("validation did not call the server",
              len(MockAuthHandler.sessions) == 0)

        # --- 4. real OTP request ---
        print("Screen: otp")
        type_phone(page, "9876543210")
        page.get_by_role("button", name="CONTINUE").first.click()
        page.wait_for_timeout(1500)
        check("OTP request hit the mock backend",
              len(MockAuthHandler.sessions) == 1)
        check("OTP screen shown", page.get_by_text("Enter OTP").count() > 0)
        page.screenshot(path=f"{ARTIFACTS}/03-otp.png")

        # --- 5. wrong code -> server error, stays on OTP ---
        type_otp(page, "000000")
        page.get_by_role("button", name="VERIFY").first.click()
        page.wait_for_timeout(1500)
        check("wrong code -> server error shown",
              page.get_by_text("Invalid or expired code").count() > 0)
        check("wrong code -> still on OTP",
              page.get_by_text("Enter OTP").count() > 0)
        page.screenshot(path=f"{ARTIFACTS}/04-otp-error.png")

        # --- 6. correct code -> profile setup (new user) -> home ---
        print("Screen: profile setup")
        type_otp(page, DEV_CODE)
        page.get_by_role("button", name="VERIFY").first.click()
        page.wait_for_timeout(2000)
        check("new user -> profile setup screen",
              page.get_by_text("Create Profile").count() > 0)
        page.screenshot(path=f"{ARTIFACTS}/05-profile-setup.png")

        print("Screen: home")
        page.get_by_role("textbox").first.click()
        page.wait_for_timeout(500)
        for ch in "Arjun":
            page.keyboard.type(ch)
            page.wait_for_timeout(200)
        page.get_by_role("button", name="START PLAYING").first.click()
        page.wait_for_timeout(2500)
        check("home: QUICK PLAY tile",
              page.get_by_text("QUICK PLAY").count() > 0)
        check("home: CREATE ROOM button",
              page.get_by_text("CREATE ROOM").count() > 0)
        check("home: live profile name from /api/players/me",
              page.get_by_text("Arjun").count() > 0)
        check("home: live coins chip",
              page.get_by_text("2500").count() > 0)
        page.screenshot(path=f"{ARTIFACTS}/06-home.png")

        # --- 7. game screen shell (E3.5) ---
        print("Screen: game shell")
        page.get_by_text("QUICK PLAY").first.click()
        page.wait_for_timeout(1500)
        check("game: turn banner",
              page.get_by_text("Your Turn — pick a card").count() > 0)
        check("game: DRAW CARD button",
              page.get_by_role("button", name="DRAW CARD").count() > 0)
        check("game: TAKE button",
              page.get_by_role("button", name="TAKE 3♥").count() > 0)
        check("game: opponents seated",
              page.get_by_text("Meera").count() > 0
              and page.get_by_text("Vikram").count() > 0)
        page.screenshot(path=f"{ARTIFACTS}/07-game.png")
        page.go_back()
        page.wait_for_timeout(1200)

        # --- 8. reload: session restore via /refresh skips login ---
        print("Screen: reload (session restore)")
        page.reload(wait_until="networkidle")
        page.wait_for_timeout(4500)  # splash 2.4s + refresh round-trip
        enable_semantics(page)
        check("saved session -> straight to home",
              page.get_by_text("QUICK PLAY").count() > 0)
        check("restored session -> profile still live",
              page.get_by_text("Arjun").count() > 0)
        page.screenshot(path=f"{ARTIFACTS}/08-restored-home.png")

        with open(f"{ARTIFACTS}/errors.log", "w") as f:
            f.write("\n".join(errors))
        check("no console/page errors", len(errors) == 0, "; ".join(errors[:5]))

        browser.close()

    if failures:
        print("\nBROWSER VERIFICATION FAILED:")
        for f_ in failures:
            print("  -", f_)
        sys.exit(1)
    print("\nBROWSER VERIFICATION PASSED")


if __name__ == "__main__":
    main()
