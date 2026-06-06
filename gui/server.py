#!/usr/bin/env python3
# ============================================================================
#  server.py  -  Backend della GUI "Control Center" della CyberSec AI VM
#  Solo libreria standard. Ascolta su 127.0.0.1 (sicuro, non esposto).
# ============================================================================
import json, os, shutil, subprocess, urllib.request, http.server, socketserver
from urllib.parse import urlparse, parse_qs

HERE = os.path.dirname(os.path.abspath(__file__))
TUT_DIR = "/opt/cybersec/tutorials"
PORT = int(os.environ.get("CYBERGUI_PORT", "8910"))

with open(os.path.join(HERE, "tools.json")) as f:
    DATA = json.load(f)

# Indici di sicurezza: comandi/azioni ammessi
TOOLS = {t["bin"]: t for c in DATA["categories"] for t in c["tools"]}
SOCK = {s["id"] for s in DATA["soclab"]}

def installed(binname):
    return shutil.which(binname) is not None

def env_gui():
    e = dict(os.environ)
    e.setdefault("DISPLAY", ":0")
    return e

def launch(binname):
    t = TOOLS.get(binname)
    if not t:
        return False, "tool sconosciuto"
    if not installed(binname):
        return False, "tool non installato"
    cmd = t["cmd"]
    try:
        if t.get("term"):
            full = f'x-terminal-emulator -e bash -c "{cmd}; echo; echo [Premi Invio per chiudere]; read"'
        else:
            full = cmd
        subprocess.Popen(["setsid", "bash", "-lc", full + " &"], env=env_gui(),
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True, "avviato"
    except Exception as ex:
        return False, str(ex)

def soclab(stack, action):
    if stack not in SOCK or action not in ("up", "down"):
        return False, "richiesta non valida"
    try:
        subprocess.Popen(["setsid", "bash", "-lc",
                          f'x-terminal-emulator -e bash -c "soclab {stack} {action}; echo; read"'],
                         env=env_gui(), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True, f"soclab {stack} {action}"
    except Exception as ex:
        return False, str(ex)

def ai_ask(prompt):
    body = json.dumps({"model": "cyberai", "prompt": prompt, "stream": False}).encode()
    try:
        req = urllib.request.Request("http://localhost:11434/api/generate", data=body,
                                     headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=120) as r:
            return json.loads(r.read()).get("response", "(nessuna risposta)")
    except Exception:
        # fallback su llama3.2
        try:
            body2 = json.dumps({"model": "llama3.2", "prompt": prompt, "stream": False}).encode()
            req = urllib.request.Request("http://localhost:11434/api/generate", data=body2,
                                         headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.loads(r.read()).get("response", "(nessuna risposta)")
        except Exception as ex:
            return f"AI non disponibile. Avvia il servizio: sudo systemctl start ollama\n({ex})"

def status():
    ai = False
    try:
        urllib.request.urlopen("http://localhost:11434/api/tags", timeout=2); ai = True
    except Exception:
        ai = False
    docker = shutil.which("docker") is not None and subprocess.call(
        ["bash", "-lc", "docker info >/dev/null 2>&1"]) == 0
    return {"ai": ai, "docker": docker,
            "installed": {b: installed(b) for b in TOOLS}}

def tutorial(name):
    safe = "".join(c for c in name if c.isalnum() or c in "-_")
    p = os.path.join(TUT_DIR, safe + ".md")
    if os.path.isfile(p):
        return open(p, encoding="utf-8", errors="ignore").read()
    return "# Tutorial non disponibile\nApri questo tool e usa il pulsante AI per una guida."

class H(http.server.BaseHTTPRequestHandler):
    def _send(self, code, ctype, body):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):  # silenzia il log
        pass

    def do_GET(self):
        u = urlparse(self.path); q = parse_qs(u.query)
        if u.path in ("/", "/index.html"):
            return self._send(200, "text/html; charset=utf-8",
                              open(os.path.join(HERE, "index.html"), "rb").read())
        if u.path == "/tools.json":
            return self._send(200, "application/json",
                              json.dumps(DATA).encode())
        if u.path == "/api/status":
            return self._send(200, "application/json", json.dumps(status()).encode())
        if u.path == "/api/launch":
            ok, msg = launch(q.get("bin", [""])[0])
            return self._send(200, "application/json", json.dumps({"ok": ok, "msg": msg}).encode())
        if u.path == "/api/tutorial":
            return self._send(200, "text/plain; charset=utf-8",
                              tutorial(q.get("name", [""])[0]).encode())
        return self._send(404, "text/plain", b"not found")

    def do_POST(self):
        u = urlparse(self.path)
        n = int(self.headers.get("Content-Length", 0))
        data = json.loads(self.rfile.read(n) or b"{}")
        if u.path == "/api/soclab":
            ok, msg = soclab(data.get("stack", ""), data.get("action", ""))
            return self._send(200, "application/json", json.dumps({"ok": ok, "msg": msg}).encode())
        if u.path == "/api/ai":
            ans = ai_ask(data.get("prompt", ""))
            return self._send(200, "application/json", json.dumps({"answer": ans}).encode())
        return self._send(404, "text/plain", b"not found")

if __name__ == "__main__":
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("127.0.0.1", PORT), H) as httpd:
        print(f"CyberSec GUI su http://127.0.0.1:{PORT}")
        httpd.serve_forever()
