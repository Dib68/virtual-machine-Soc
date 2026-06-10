#!/usr/bin/env python3
"""Test d'integrazione del server GUI: AI in streaming via HTTP e concorrenza.
Avvia un finto Ollama su una porta libera e il server reale (multi-thread),
poi verifica che la risposta arrivi a pezzi e che lo streaming NON blocchi le
altre richieste. Non richiede Ollama ne' tool reali installati."""
import os, sys, json, time, threading, http.server, socketserver, importlib.util, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = []
def ck(n, c): P.append((n, bool(c))); print(("PASS " if c else "FAIL ") + n)

# --- finto Ollama (NDJSON in streaming) su porta libera ---
class TServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True; allow_reuse_address = True
class FakeOllama(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        self.send_response(200); self.end_headers(); self.wfile.write(b'{"models":[]}')
    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0)); json.loads(self.rfile.read(n) or b"{}")
        self.send_response(200); self.end_headers()
        for i in range(5):
            self.wfile.write((json.dumps({"message": {"content": "tok%d " % i}, "done": False}) + "\n").encode())
            self.wfile.flush(); time.sleep(0.12)
        self.wfile.write((json.dumps({"message": {"content": ""}, "done": True}) + "\n").encode())

fake = TServer(("127.0.0.1", 0), FakeOllama)
fake_port = fake.server_address[1]
threading.Thread(target=fake.serve_forever, daemon=True).start()

# --- carica il server reale e puntalo al finto Ollama ---
spec = importlib.util.spec_from_file_location("srv", os.path.join(ROOT, "gui", "server.py"))
srv = importlib.util.module_from_spec(spec); spec.loader.exec_module(srv)
srv.OLLAMA = "http://127.0.0.1:%d" % fake_port

httpd = srv.make_server(0)
port = httpd.server_address[1]
threading.Thread(target=httpd.serve_forever, daemon=True).start()
time.sleep(0.3)
BASE = "http://127.0.0.1:%d" % port

def post_stream(path, obj, timeout=15):
    req = urllib.request.Request(BASE + path, data=json.dumps(obj).encode(),
                                 headers={"Content-Type": "application/json"})
    return urllib.request.urlopen(req, timeout=timeout)

# 1) la risposta arriva e contiene tutti i pezzi, in ordine
with post_stream("/api/ai_stream", {"prompt": "ciao"}) as r:
    body = r.read().decode("utf-8", "ignore")
ck("streaming HTTP restituisce il testo", body == "tok0 tok1 tok2 tok3 tok4 ")

# 2) il server e' multi-thread: GET / risponde subito mentre uno stream e' attivo
res = {}
def long_stream():
    t0 = time.perf_counter()
    with post_stream("/api/ai_stream", {"prompt": "lungo"}) as r:
        r.read()
    res["dt"] = time.perf_counter() - t0
th = threading.Thread(target=long_stream); th.start(); time.sleep(0.2)
t0 = time.perf_counter()
page = urllib.request.urlopen(BASE + "/", timeout=5).read()
page_dt = time.perf_counter() - t0
th.join()
ck("la pagina si carica durante lo streaming", len(page) > 1000)
ck("lo streaming non blocca le altre richieste", page_dt < 0.5 and res.get("dt", 0) > 0.4)

# 3) endpoint non-streaming compatibile (/api/ai)
ans = json.loads(post_stream("/api/ai", {"prompt": "ciao"}).read())["answer"]
ck("endpoint /api/ai (non-stream) compatibile", ans == "tok0 tok1 tok2 tok3 tok4")

# 4) endpoint /api/health
h = json.loads(urllib.request.urlopen(BASE + "/api/health", timeout=5).read())
ck("/api/health risponde con versione", h.get("ok") is True and isinstance(h.get("version"), str))

# 5) hardening: corpo JSON malformato -> 400 (non crasha il server)
import urllib.error
try:
    bad = urllib.request.Request(BASE + "/api/ai", data=b"{non-json",
                                 headers={"Content-Type": "application/json"})
    urllib.request.urlopen(bad, timeout=5); code = 200
except urllib.error.HTTPError as e:
    code = e.code
ck("JSON malformato gestito (400)", code == 400)

httpd.shutdown(); fake.shutdown()
passed = sum(1 for _, c in P if c); total = len(P)
print("\n=== STREAM: %d/%d test superati ===" % (passed, total))
sys.exit(0 if passed == total else 1)
