#!/usr/bin/env python3
"""Test funzionali del backend della GUI (server.py).
Usa un terminale finto e un finto Ollama: non richiede tool reali installati."""
import os, sys, importlib.util, glob, time, threading, json, http.server, socketserver, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GUI = os.path.join(ROOT, "gui")
WORK = tempfile.mkdtemp(prefix="guitest_")
os.chdir(GUI)

# PATH con binario finto + terminale finto
binp = os.path.join(WORK, "bin"); os.makedirs(binp, exist_ok=True)
open(binp+"/faketool","w").write("#!/usr/bin/env bash\necho ok\n"); os.chmod(binp+"/faketool",0o755)
termlog = os.path.join(WORK, "term.log"); open(termlog,"w").close()
open(binp+"/qterminal","w").write('#!/usr/bin/env bash\necho "QTERM $@" >> "%s"\n' % termlog); os.chmod(binp+"/qterminal",0o755)
os.environ["PATH"] = binp + ":" + os.environ["PATH"]
os.environ["DISPLAY"] = ":0"

spec = importlib.util.spec_from_file_location("srv", os.path.join(GUI,"server.py"))
srv = importlib.util.module_from_spec(spec); spec.loader.exec_module(srv)
srv.TUT_DIR = os.path.join(ROOT, "menu", "tutorials")

P = []
def ck(n, c): P.append((n, bool(c))); print(("PASS " if c else "FAIL ") + n)

# stato
st = srv.status()
ck("status ha le chiavi", all(k in st for k in ("ai","docker","installed")))
ck("status elenca i tool", len(st["installed"]) >= 40)
# tutorial
ck("tutorial reale (nmap)", "Nmap" in srv.tutorial("nmap"))
ck("tutorial fallback", "non disponibile" in srv.tutorial("zzz_inesistente").lower())
ck("tutorial path-safe", "non disponibile" in srv.tutorial("../../etc/passwd").lower())
# dati
ck("tools.json categorie>=13", len(srv.DATA["categories"]) >= 13)
ck("tools.json soclab==7", len(srv.DATA["soclab"]) == 7)
# launch tool finto (term)
srv.TOOLS["faketool"] = {"bin":"faketool","name":"Fake","desc":"x","cmd":"faketool","tut":"nmap","term":True}
ok,_ = srv.launch("faketool"); time.sleep(1)
log = open(termlog).read()
ck("launch term: ritorna ok", ok)
ck("launch term: apre il terminale", "QTERM" in log)
scr = sorted(glob.glob("/tmp/cyberrun_*.sh"))
ck("launch term: crea script", bool(scr) and "faketool" in open(scr[-1]).read())
# launch tool non installato
ok2,msg2 = srv.launch("nmap")
ck("tool non installato gestito", (not ok2) and "non installato" in msg2)
# soclab validazione
ok3,_ = srv.soclab("targets","up"); ck("soclab valido accettato", ok3)
ok4,m4 = srv.soclab("hacker","boom"); ck("soclab non valido rifiutato", (not ok4))
# install on-demand
srv.TOOLS["needinst"] = {"bin":"needinst","name":"X","desc":"y","cmd":"needinst","tut":"nmap","term":True,"pkg":"needinst-pkg"}
oi,mi = srv.install("needinst")
import glob as _g, time as _t; _t.sleep(0.5)
scr2 = sorted(_g.glob("/tmp/install_*.sh"))
ck("install: ritorna ok", oi)
ck("install: crea script apt", bool(scr2) and "apt-get install" in open(scr2[-1]).read())
srv.TOOLS["nopkg"] = {"bin":"nopkg","name":"Z","desc":"y","cmd":"nopkg","tut":"nmap","term":True,"pkg":""}
on,mn = srv.install("nopkg")
ck("install senza pkg gestito", (not on) and "COMPLETA" in mn)
ok_ai,_ = srv.install("faketool")  # gia' installato
ck("install gia' installato gestito", not ok_ai)

# AI: senza servizio -> messaggio gestito
ck("AI senza servizio gestita", "non disponibile" in srv.ai_ask("ciao").lower())
# AI: con finto Ollama
class F(http.server.BaseHTTPRequestHandler):
    def log_message(self,*a): pass
    def do_GET(self): self.send_response(200); self.end_headers(); self.wfile.write(b'{"models":[]}')
    def do_POST(self):
        n=int(self.headers.get("Content-Length",0)); self.rfile.read(n)
        self.send_response(200); self.end_headers(); self.wfile.write(json.dumps({"response":"OK-AI"}).encode())
socketserver.TCPServer.allow_reuse_address = True
httpd = None
try:
    httpd = socketserver.TCPServer(("127.0.0.1",11434), F)
    threading.Thread(target=httpd.serve_forever, daemon=True).start(); time.sleep(0.4)
    ck("AI proxy risponde", "OK-AI" in srv.ai_ask("ciao"))
    ck("status rileva AI attivo", srv.status()["ai"] is True)
finally:
    if httpd: httpd.shutdown(); httpd.server_close()

passed = sum(1 for _,c in P if c); total = len(P)
print("\n=== GUI: %d/%d test superati ===" % (passed, total))
sys.exit(0 if passed == total else 1)
