#!/usr/bin/env python3
"""Test funzionali del backend della GUI (server.py).
Usa un terminale finto e un finto Ollama: non richiede tool reali installati."""
import os, sys, importlib.util, glob, time, threading, json, http.server, socketserver, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GUI = os.path.join(ROOT, "gui")
WORK = tempfile.mkdtemp(prefix="guitest_")
os.chdir(GUI)

# PATH con binario finto + terminale finto.
# Su Windows shutil.which() trova solo i file con estensione in PATHEXT, quindi
# creiamo lo stub anche come .cmd (su Linux resta il classico file eseguibile).
binp = os.path.join(WORK, "bin"); os.makedirs(binp, exist_ok=True)
def _stub(name, body):
    open(binp+"/"+name,"w").write(body); os.chmod(binp+"/"+name,0o755)
    if sys.platform == "win32":
        open(binp+"/"+name+".cmd","w").write("@echo off\r\n")
_stub("faketool", "#!/usr/bin/env bash\necho ok\n")
termlog = os.path.join(WORK, "term.log"); open(termlog,"w").close()
open(binp+"/qterminal","w").write('#!/usr/bin/env bash\necho "QTERM $@" >> "%s"\n' % termlog.replace("\\","/")); os.chmod(binp+"/qterminal",0o755)
os.environ["PATH"] = binp + os.pathsep + os.environ["PATH"]
os.environ["DISPLAY"] = ":0"
TMP = tempfile.gettempdir()   # stessa temp dir usata dal server (portabile)

spec = importlib.util.spec_from_file_location("srv", os.path.join(GUI,"server.py"))
srv = importlib.util.module_from_spec(spec); spec.loader.exec_module(srv)
srv.TUT_DIR = os.path.join(ROOT, "menu", "tutorials")

P = []
def ck(n, c): P.append((n, bool(c))); print(("PASS " if c else "FAIL ") + n)

# stato
st = srv.status()
ck("status ha le chiavi", all(k in st for k in ("ai","docker","installed","version","models")))
ck("status elenca i tool", len(st["installed"]) >= 40)
ck("status riporta la versione", isinstance(st["version"], str) and st["version"] not in ("", "?"))
# scelta del modello AI
ck("ordine modello: scelto per primo", srv._model_order("llama3.2")[0] == "llama3.2"
   and set(srv._model_order("llama3.2")) == set(srv.AI_MODELS))
ck("ordine modello: invalido -> default", srv._model_order("inesistente") == srv.AI_MODELS)
# tutorial
ck("tutorial reale (nmap)", "Nmap" in srv.tutorial("nmap"))
ck("tutorial fallback", "non disponibile" in srv.tutorial("zzz_inesistente").lower())
ck("tutorial path-safe", "non disponibile" in srv.tutorial("../../etc/passwd").lower())
# dati
ck("tools.json categorie>=13", len(srv.DATA["categories"]) >= 13)
ck("tools.json soclab==7", len(srv.DATA["soclab"]) == 7)
# launch tool finto (term)
# Verifica se 'bash' e' realmente funzionante (su Windows puo' risolvere allo
# stub WSL senza distro: in quel caso il terminale finto non parte e i relativi
# controlli vengono SALTATI, non considerati falliti).
import subprocess as _sp
def _bash_ok():
    try:
        r = _sp.run(["bash", "-c", "echo BASHOK"], capture_output=True, text=True, timeout=8)
        return r.stdout.strip() == "BASHOK"
    except Exception:
        return False
BASH_OK = _bash_ok()
srv.TOOLS["faketool"] = {"bin":"faketool","name":"Fake","desc":"x","cmd":"faketool","tut":"nmap","term":True}
ok,_ = srv.launch("faketool"); time.sleep(1)
log = open(termlog).read()
ck("launch term: ritorna ok", ok)
if BASH_OK:
    ck("launch term: apre il terminale", "QTERM" in log)
else:
    print("SKIP launch term: apre il terminale (bash non funzionante in questo ambiente)")
scr = sorted(glob.glob(os.path.join(TMP, "cyberrun_*.sh")), key=os.path.getmtime)
ck("launch term: crea script", bool(scr) and "faketool" in open(scr[-1]).read())
# launch tool non installato
ok2,msg2 = srv.launch("nmap")
ck("tool non installato gestito", (not ok2) and "non installato" in msg2)
# soclab validazione
ok3,_ = srv.soclab("targets","up"); ck("soclab valido accettato", ok3)
ok4,m4 = srv.soclab("hacker","boom"); ck("soclab non valido rifiutato", (not ok4))
# stato degli stack SOC
_ss = srv.soclab_status()
ck("soclab_status elenca tutti gli stack", set(_ss.keys()) == srv.SOCK and all(isinstance(v, bool) for v in _ss.values()))
# install on-demand
srv.TOOLS["needinst"] = {"bin":"needinst","name":"X","desc":"y","cmd":"needinst","tut":"nmap","term":True,"pkg":"needinst-pkg"}
oi,mi = srv.install("needinst")
import glob as _g, time as _t; _t.sleep(0.5)
scr2 = sorted(_g.glob(os.path.join(TMP, "install_*.sh")), key=os.path.getmtime)
ck("install: ritorna ok", oi)
ck("install: crea script apt", bool(scr2) and "apt-get install" in open(scr2[-1]).read())
srv.TOOLS["nopkg"] = {"bin":"nopkg","name":"Z","desc":"y","cmd":"nopkg","tut":"nmap","term":True,"pkg":""}
on,mn = srv.install("nopkg")
ck("install senza pkg gestito", (not on) and "COMPLETA" in mn)
ok_ai,_ = srv.install("faketool")  # gia' installato
ck("install gia' installato gestito", not ok_ai)
# install in blocco dei pacchetti mancanti
srv.TOOLS["bulk1"] = {"bin":"bulk1","name":"B1","desc":"y","cmd":"bulk1","tut":"nmap","term":True,"pkg":"pkg-uno"}
srv.TOOLS["bulk2"] = {"bin":"bulk2","name":"B2","desc":"y","cmd":"bulk2","tut":"nmap","term":True,"pkg":"pkg-due pkg-uno"}
mp = srv.missing_pkgs()
ck("missing_pkgs: raccoglie e deduplica", "pkg-uno" in mp and "pkg-due" in mp and mp.count("pkg-uno")==1)
okb, nb, _ = srv.install_missing(); _t.sleep(0.5)
scr3 = sorted(_g.glob(os.path.join(TMP, "install_*.sh")), key=os.path.getmtime)
ck("install_missing: avvia un solo apt", okb and nb>0 and "apt-get install" in open(scr3[-1]).read()
   and "pkg-uno" in open(scr3[-1]).read())
ck("status conta i pacchetti mancanti", "missing" in st and isinstance(st["missing"], int))
# install in streaming: costruzione comando + percorso "niente da fare"
_cmd = srv.install_stream_cmd()
ck("install_stream_cmd costruisce apt", bool(_cmd) and "apt-get install" in _cmd and "pkg-uno" in _cmd)
_om = srv.missing_pkgs; srv.missing_pkgs = lambda: []
ck("install_missing_stream: nulla da fare", "gia'" in "".join(srv.install_missing_stream()))
srv.missing_pkgs = _om

# AI: senza servizio -> messaggio gestito
ck("AI senza servizio gestita", "non disponibile" in srv.ai_ask("ciao").lower())
ck("AI prompt vuoto gestito", "domanda" in srv.ai_ask("   ").lower())
# Costruzione messaggi: cronologia + domanda, segnaposto "..." e ruoli ignoti scartati
_m = srv._build_messages("e poi?", [
    {"role":"user","content":"ciao"}, {"role":"assistant","content":"salve"},
    {"role":"assistant","content":"..."}, {"role":"system","content":"x"}])
ck("messaggi: scarta '...' e ruoli ignoti", len(_m)==3 and _m[-1]=={"role":"user","content":"e poi?"})
# hardening: prompt e cronologia troncati al limite massimo
_long = srv._build_messages("x"*50000, [{"role":"user","content":"y"*50000}])
ck("prompt troncato al limite", all(len(mm["content"]) <= srv.MAX_PROMPT for mm in _long))
# AI: con finto Ollama (endpoint /api/chat). Cattura il body per verificare la memoria.
LAST = {}
class F(http.server.BaseHTTPRequestHandler):
    def log_message(self,*a): pass
    def do_GET(self): self.send_response(200); self.end_headers(); self.wfile.write(b'{"models":[]}')
    def do_POST(self):
        n=int(self.headers.get("Content-Length",0)); raw=self.rfile.read(n)
        try: body=json.loads(raw or b"{}")
        except Exception: body={}
        LAST.clear(); LAST.update(body)
        self.send_response(200); self.end_headers()
        if body.get("stream"):   # NDJSON: una riga per pezzo di testo
            for part in ("OK","-","AI"):
                self.wfile.write((json.dumps({"message":{"content":part},"done":False})+"\n").encode())
            self.wfile.write((json.dumps({"message":{"content":""},"done":True})+"\n").encode())
        else:
            self.wfile.write(json.dumps({"message":{"content":"OK-AI"}}).encode())
socketserver.TCPServer.allow_reuse_address = True
httpd = None
try:
    httpd = socketserver.TCPServer(("127.0.0.1",11434), F)
    threading.Thread(target=httpd.serve_forever, daemon=True).start(); time.sleep(0.4)
    ck("AI: _ensure_ollama rileva il servizio attivo", srv._ensure_ollama() is True)
    ck("AI proxy risponde", "OK-AI" in srv.ai_ask("ciao"))
    ck("AI streaming a pezzi", "".join(srv.ai_stream("ciao")) == "OK-AI")
    ck("status rileva AI attivo", srv.status()["ai"] is True)
    # il modello scelto deve essere inoltrato a Ollama
    srv.ai_ask("x", model="llama3.2"); ck("AI inoltra il modello scelto", LAST.get("model") == "llama3.2")
    srv.ai_ask("x", model="inesistente"); ck("AI ignora un modello invalido", LAST.get("model") == "cyberai")
    # la "modalita'" (persona) aggiunge un messaggio di sistema
    srv.ai_ask("x", persona="blueteam")
    m0 = (LAST.get("messages") or [{}])[0]
    ck("AI applica la modalita' scelta", m0.get("role") == "system" and "Blue Team" in m0.get("content", ""))
    srv.ai_ask("x", persona="inesistente")
    ck("AI ignora una modalita' invalida", (LAST.get("messages") or [{}])[0].get("role") == "user")
    # con cronologia: il backend deve inoltrare i messaggi precedenti a Ollama
    srv.ai_ask("e poi?", history=[{"role":"user","content":"cos'e' nmap?"},
                                   {"role":"assistant","content":"uno scanner"}])
    msgs = LAST.get("messages", [])
    ck("AI conserva la cronologia", len(msgs)==3 and msgs[0]["content"]=="cos'e' nmap?"
       and msgs[-1]["content"]=="e poi?")
finally:
    if httpd: httpd.shutdown(); httpd.server_close()

passed = sum(1 for _,c in P if c); total = len(P)
print("\n=== GUI: %d/%d test superati ===" % (passed, total))
sys.exit(0 if passed == total else 1)
