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
OLLAMA = os.environ.get("OLLAMA_HOST", "http://localhost:11434")
# Modelli usati per l'AI: prima lo specializzato, poi il fallback leggero.
AI_MODELS = ("cyberai", "llama3.2")
# Massimo di messaggi di cronologia tenuti in memoria per conversazione.
AI_HISTORY_MAX = 12
# Limiti di sicurezza: lunghezza massima del prompt e del corpo richiesta.
MAX_PROMPT = 16000
MAX_BODY = 4 * 1024 * 1024
# "Modalita'" dell'assistente: istruzione extra di sistema in base al contesto.
PERSONAS = {
    "redteam":  "Adotta il punto di vista del Red Team / penetration tester: "
                "enfatizza ricognizione, sfruttamento, evasione e post-exploitation, "
                "sempre in ambito autorizzato.",
    "blueteam": "Adotta il punto di vista del Blue Team / SOC analyst: enfatizza "
                "detection, logging, incident response, threat hunting e hardening.",
    "explain":  "Spiega in modo molto semplice, adatto a un principiante, con piccole "
                "analogie e passaggi numerati; evita gergo non spiegato.",
}

def _read_version():
    try:
        with open(os.path.join(HERE, "..", "VERSION")) as f:
            return f.read().strip()
    except Exception:
        return "?"

VERSION = _read_version()

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

def _popen_bg(cmd):
    # Avvia un comando in background, slegato dalla GUI. Usa 'setsid' se c'e'
    # (Kali) per staccare del tutto il processo; altrimenti ricade su
    # start_new_session (portabile, utile anche fuori da Linux/per i test).
    pre = ["setsid"] if shutil.which("setsid") else []
    return subprocess.Popen(pre + ["bash", "-lc", cmd], env=env_gui(),
                            start_new_session=True,
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def _stream_cmd(cmd):
    # Esegue un comando e produce il suo output riga per riga (per lo streaming).
    p = subprocess.Popen(["bash", "-lc", cmd], env=env_gui(),
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    try:
        for line in iter(p.stdout.readline, b""):
            yield line.decode("utf-8", "ignore")
    finally:
        try:
            p.stdout.close()
        except Exception:
            pass
        p.wait()

def _run_in_terminal(inner_cmd, tag="cyberrun"):
    import tempfile, glob, time
    tmp = tempfile.gettempdir()   # /tmp su Linux; portabile altrove (test)
    # pulizia script temporanei vecchi (>1h)
    for old in (glob.glob(os.path.join(tmp, "cyberrun_*.sh"))
                + glob.glob(os.path.join(tmp, "soclab_*.sh"))
                + glob.glob(os.path.join(tmp, "install_*.sh"))):
        try:
            if time.time() - os.path.getmtime(old) > 3600:
                os.remove(old)
        except Exception:
            pass
    fd, path = tempfile.mkstemp(prefix=tag + "_", suffix=".sh", dir=tmp)
    with os.fdopen(fd, "w") as f:
        f.write("#!/usr/bin/env bash\n" + inner_cmd +
                "\necho; echo '[Premi Invio per chiudere questa finestra]'; read\n")
    os.chmod(path, 0o755)
    term = ("qterminal -e {p} || xfce4-terminal -e {p} || x-terminal-emulator -e {p} "
            "|| gnome-terminal -- {p} || xterm -e {p} || konsole -e {p}").format(p=path)
    _popen_bg(term)

def launch(binname):
    t = TOOLS.get(binname)
    if not t:
        return False, "tool sconosciuto"
    if not installed(binname):
        return False, "tool non installato"
    cmd = t["cmd"]
    try:
        if t.get("term"):
            _run_in_terminal(cmd)
        else:
            _popen_bg(cmd)
        return True, "avviato"
    except Exception as ex:
        return False, str(ex)

def soclab(stack, action):
    if stack not in SOCK or action not in ("up", "down"):
        return False, "richiesta non valida"
    try:
        _run_in_terminal("soclab %s %s" % (stack, action), tag="soclab")
        return True, "soclab %s %s avviato" % (stack, action)
    except Exception as ex:
        return False, str(ex)

def soclab_status():
    # Quali stack SOC risultano attivi (in base ai container Docker in esecuzione).
    running = {s: False for s in SOCK}
    if not shutil.which("docker"):
        return running
    try:
        out = subprocess.run(["bash", "-lc", "docker ps --format '{{.Names}}'"],
                             capture_output=True, text=True, timeout=5).stdout.lower()
    except Exception:
        return running
    for s in SOCK:
        if s.lower() in out:
            running[s] = True
    return running

def install(binname):
    t = TOOLS.get(binname)
    if not t:
        return False, "tool sconosciuto"
    if installed(binname):
        return False, "gia' installato"
    pkg = t.get("pkg", "")
    if not pkg:
        return False, "questo strumento si installa con COMPLETA-INSTALLAZIONE"
    try:
        cmd = ("echo 'Installazione di %s ...'; sudo apt-get update; "
               "sudo apt-get install -y %s; echo; echo 'Fatto.'") % (pkg, pkg)
        _run_in_terminal(cmd, tag="install")
        return True, "installazione avviata: " + pkg
    except Exception as ex:
        return False, str(ex)

def missing_pkgs():
    # Pacchetti apt degli strumenti non ancora installati (con pkg noto),
    # senza duplicati e mantenendo l'ordine.
    seen, out = set(), []
    for b, t in TOOLS.items():
        if installed(b):
            continue
        for p in (t.get("pkg", "") or "").split():
            if p not in seen:
                seen.add(p); out.append(p)
    return out

def _apt_loop_cmd(pkgs, sudo="sudo"):
    # Installa i pacchetti UNO ALLA VOLTA: se un nome non esiste viene SALTATO,
    # senza far fallire l'intera operazione (apt si fermerebbe al primo errore).
    plist = " ".join(pkgs)
    return (
        "%s apt-get update; ok=0; ko=0; "
        "for p in %s; do echo \"== installo $p ==\"; "
        "if %s apt-get install -y \"$p\"; then ok=$((ok+1)); "
        "else echo \"   [salto] $p: non disponibile via apt\"; ko=$((ko+1)); fi; done; "
        "echo; echo \"Completato: $ok installati, $ko saltati. "
        "I tool non-apt (es. volatility3, nuclei) si installano con COMPLETA-INSTALLAZIONE.\""
    ) % (sudo, plist, sudo)

def install_missing():
    # Installa i pacchetti apt mancanti (uno alla volta) in un terminale.
    pkgs = missing_pkgs()
    if not pkgs:
        return False, 0, "tutti gli strumenti con pacchetto apt sono gia' installati"
    try:
        _run_in_terminal(_apt_loop_cmd(pkgs, "sudo"), tag="install")
        return True, len(pkgs), "installazione di %d pacchetti avviata" % len(pkgs)
    except Exception as ex:
        return False, 0, str(ex)

def install_stream_cmd():
    # Comando per installare i pacchetti mancanti (sudo non interattivo, in streaming).
    pkgs = missing_pkgs()
    if not pkgs:
        return None
    return _apt_loop_cmd(pkgs, "sudo -n")

def install_missing_stream():
    # Installa i pacchetti mancanti mostrando l'output in tempo reale.
    cmd = install_stream_cmd()
    if not cmd:
        yield "Tutti gli strumenti con pacchetto apt sono gia' installati.\n"
        return
    yield "Avvio installazione dei pacchetti mancanti...\n"
    yield "(se chiede la password, usa invece il pulsante che apre il terminale)\n\n"
    for chunk in _stream_cmd(cmd):
        yield chunk
    yield "\n== Operazione terminata ==\n"

def _ollama_chat_stream(model, messages, timeout=300):
    # Streaming: Ollama risponde con una riga JSON (NDJSON) per ogni pezzo di testo.
    body = json.dumps({"model": model, "messages": messages, "stream": True}).encode()
    req = urllib.request.Request(OLLAMA + "/api/chat", data=body,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        for raw in r:
            raw = raw.strip()
            if not raw:
                continue
            try:
                d = json.loads(raw)
            except Exception:
                continue
            # /api/chat -> {"message":{"content":...}}; tolleriamo anche {"response":...}
            chunk = (d.get("message") or {}).get("content") or d.get("response") or ""
            if chunk:
                yield chunk
            if d.get("done"):
                break

def _build_messages(prompt, history, persona=None):
    # Costruisce la conversazione: (eventuale modalita') + cronologia + domanda.
    # Il prompt di sistema (ruolo, regole) e' gia' dentro il modello 'cyberai'.
    msgs = []
    if persona in PERSONAS:
        msgs.append({"role": "system", "content": PERSONAS[persona]})
    hist = []
    for m in (history or []):
        role = m.get("role")
        content = (m.get("content") or "").strip()[:MAX_PROMPT]
        if role in ("user", "assistant") and content and content != "...":
            hist.append({"role": role, "content": content})
    msgs += hist[-AI_HISTORY_MAX:]           # limita la memoria (e i token)
    msgs.append({"role": "user", "content": (prompt or "")[:MAX_PROMPT]})
    return msgs

def _model_order(model):
    # Se l'utente sceglie un modello valido lo prova per primo, poi i fallback.
    if model in AI_MODELS:
        return (model,) + tuple(m for m in AI_MODELS if m != model)
    return AI_MODELS

def ai_stream(prompt, history=None, model=None, persona=None):
    """Genera la risposta dell'AI a pezzi (streaming), mantenendo il contesto.
    history: lista di {"role": "user"|"assistant", "content": "..."} precedenti.
    model: modello preferito ("cyberai" o "llama3.2"); altrimenti ordine di default.
    persona: modalita' ("redteam"|"blueteam"|"explain") che orienta le risposte."""
    if not (prompt or "").strip():
        yield "Scrivi una domanda."
        return
    messages = _build_messages(prompt, history, persona)
    last_err = None
    for m in _model_order(model):         # modello scelto, poi i fallback
        try:
            produced = False
            for chunk in _ollama_chat_stream(m, messages):
                produced = True
                yield chunk
            if produced:
                return
        except Exception as ex:
            last_err = ex
    yield ("AI non disponibile. Avvia il servizio: sudo systemctl start ollama"
           + (f"\n({last_err})" if last_err else ""))

def ai_ask(prompt, history=None, model=None, persona=None):
    """Versione non-streaming: raccoglie tutta la risposta in una stringa."""
    return "".join(ai_stream(prompt, history, model, persona)).strip() or "(nessuna risposta)"

def ai_models():
    # Modelli realmente disponibili su Ollama (per la scelta nella GUI).
    try:
        with urllib.request.urlopen(OLLAMA + "/api/tags", timeout=2) as r:
            d = json.loads(r.read())
        names = sorted({(m.get("name") or "").split(":")[0] for m in d.get("models", [])})
        return True, [n for n in names if n]
    except Exception:
        return False, []

def status():
    ai, models = ai_models()
    docker = shutil.which("docker") is not None and subprocess.call(
        ["bash", "-lc", "docker info >/dev/null 2>&1"]) == 0
    inst = {b: installed(b) for b in TOOLS}
    missing = sum(1 for b, t in TOOLS.items()
                  if not inst[b] and (t.get("pkg", "") or "").strip())
    return {"ai": ai, "docker": docker, "version": VERSION, "models": models,
            "missing": missing, "installed": inst}

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
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):  # silenzia il log
        pass

    def _host_ok(self):
        # Difesa da DNS-rebinding: accetta solo Host locali (qualsiasi porta).
        h = (self.headers.get("Host") or "").strip().lower()
        if not h:
            return True
        if h.startswith("["):            # IPv6: [::1]:porta
            h = h[1:].split("]")[0]
        elif ":" in h:                   # host:porta
            h = h.rsplit(":", 1)[0]
        return h in ("127.0.0.1", "localhost", "::1")

    def do_GET(self):
        if not self._host_ok():
            return self._send(403, "text/plain", b"host non consentito")
        u = urlparse(self.path); q = parse_qs(u.query)
        if u.path in ("/", "/index.html"):
            return self._send(200, "text/html; charset=utf-8",
                              open(os.path.join(HERE, "index.html"), "rb").read())
        if u.path == "/favicon.png":
            fp = os.path.join(HERE, "favicon.png")
            if os.path.isfile(fp):
                return self._send(200, "image/png", open(fp, "rb").read())
            return self._send(404, "text/plain", b"")
        if u.path == "/tools.json":
            return self._send(200, "application/json",
                              json.dumps(DATA).encode())
        if u.path == "/api/status":
            return self._send(200, "application/json", json.dumps(status()).encode())
        if u.path == "/api/soclab_status":
            return self._send(200, "application/json", json.dumps(soclab_status()).encode())
        if u.path == "/api/health":
            ai_ok, models = ai_models()
            return self._send(200, "application/json",
                              json.dumps({"ok": True, "version": VERSION,
                                          "ai": ai_ok, "models": models}).encode())
        if u.path == "/api/launch":
            ok, msg = launch(q.get("bin", [""])[0])
            return self._send(200, "application/json", json.dumps({"ok": ok, "msg": msg}).encode())
        if u.path == "/api/install":
            ok, msg = install(q.get("bin", [""])[0])
            return self._send(200, "application/json", json.dumps({"ok": ok, "msg": msg}).encode())
        if u.path == "/api/install_missing":
            ok, n, msg = install_missing()
            return self._send(200, "application/json",
                              json.dumps({"ok": ok, "count": n, "msg": msg}).encode())
        if u.path == "/api/tutorial":
            return self._send(200, "text/plain; charset=utf-8",
                              tutorial(q.get("name", [""])[0]).encode())
        return self._send(404, "text/plain", b"not found")

    def do_POST(self):
        if not self._host_ok():
            return self._send(403, "text/plain", b"host non consentito")
        u = urlparse(self.path)
        n = min(int(self.headers.get("Content-Length", 0) or 0), MAX_BODY)
        try:
            data = json.loads(self.rfile.read(n) or b"{}")
            if not isinstance(data, dict):
                data = {}
        except Exception:
            return self._send(400, "application/json", b'{"error":"json non valido"}')
        if u.path == "/api/soclab":
            ok, msg = soclab(data.get("stack", ""), data.get("action", ""))
            return self._send(200, "application/json", json.dumps({"ok": ok, "msg": msg}).encode())
        if u.path == "/api/ai":
            ans = ai_ask(data.get("prompt", ""), data.get("history"),
                         data.get("model"), data.get("persona"))
            return self._send(200, "application/json", json.dumps({"answer": ans}).encode())
        if u.path == "/api/ai_stream":
            # Risposta in streaming: invia il testo a pezzi appena arriva da Ollama.
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Cache-Control", "no-cache")
            self.end_headers()
            try:
                for chunk in ai_stream(data.get("prompt", ""), data.get("history"),
                                       data.get("model"), data.get("persona")):
                    self.wfile.write(chunk.encode("utf-8"))
                    self.wfile.flush()
            except Exception:
                pass   # client disconnesso o errore di rete: chiudiamo e basta
            return
        if u.path == "/api/install_missing_stream":
            # Installazione dei pacchetti mancanti con output in tempo reale.
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Cache-Control", "no-cache")
            self.end_headers()
            try:
                for chunk in install_missing_stream():
                    self.wfile.write(chunk.encode("utf-8"))
                    self.wfile.flush()
            except Exception:
                pass
            return
        return self._send(404, "text/plain", b"not found")

# Server multi-thread: una risposta AI in streaming (anche lunga) non blocca
# piu' le altre richieste (stato, avvio tool, tutorial).
class ThreadingServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True

def make_server(port=PORT):
    return ThreadingServer(("127.0.0.1", port), H)

if __name__ == "__main__":
    with make_server(PORT) as httpd:
        print(f"CyberSec GUI su http://127.0.0.1:{PORT}")
        httpd.serve_forever()
