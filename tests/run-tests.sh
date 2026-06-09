#!/usr/bin/env bash
# ============================================================================
#  run-tests.sh  -  Suite di test del progetto CyberSec AI VM.
#  Verifica sintassi, validita' di JSON/YAML/HCL, coerenza menu-tutorial e
#  i test funzionali della GUI. Pensata anche per la CI di GitHub.
#  Uso:  bash tests/run-tests.sh
# ============================================================================
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
FAIL=0
pass(){ echo "  [OK] $1"; }
err(){ echo "  [FAIL] $1"; FAIL=1; }

echo "== 1. Sintassi degli script shell =="
n=0
while IFS= read -r f; do
  n=$((n+1)); bash -n "$f" 2>/tmp/e || { err "$f"; cat /tmp/e; }
done < <(find provision menu soc-lab tools gui condivisa tests -name '*.sh' 2>/dev/null; ls *.sh 2>/dev/null)
[ "$FAIL" = 0 ] && pass "$n script shell validi"

echo "== 2. Python (server.py) =="
python3 -c "import ast; ast.parse(open('gui/server.py').read())" && pass "server.py sintassi valida" || err "server.py"

echo "== 3. JSON =="
python3 -c "import json; d=json.load(open('gui/tools.json')); assert len(d['categories'])>=13 and len(d['soclab'])==7" \
  && pass "tools.json valido" || err "tools.json"

echo "== 4. YAML docker-compose =="
python3 - <<'PY' && pass "tutti i docker-compose validi" || err "docker-compose"
import glob,sys
try: import yaml
except Exception: print("(pyyaml assente: salto)"); sys.exit(0)
ok=True
for f in glob.glob("soc-lab/**/docker-compose.yml",recursive=True):
    try: yaml.safe_load(open(f))
    except Exception as e: print("  ",f,e); ok=False
sys.exit(0 if ok else 1)
PY

echo "== 5. Vagrantfile (Ruby) =="
if command -v ruby >/dev/null 2>&1; then ruby -c Vagrantfile >/dev/null && pass "Vagrantfile valido" || err "Vagrantfile"
else echo "  (ruby assente: salto, sara' validato da Vagrant)"; fi

echo "== 6. Packer HCL (bilanciamento) =="
python3 -c "s=open('packer/cybersec-ai.pkr.hcl').read(); assert s.count('{')==s.count('}')" \
  && pass "packer HCL bilanciato" || err "packer HCL"

echo "== 7. Coerenza menu -> tutorial =="
miss=0
for t in $(grep -oE '\|[a-z0-9-]+$' menu/cybermenu.sh | tr -d '|' | sort -u) 00-introduzione 00-tool-richiesti-lavoro; do
  [ -f "menu/tutorials/$t.md" ] || { echo "  manca: $t"; miss=1; }
done
[ "$miss" = 0 ] && pass "ogni voce di menu ha il suo tutorial" || err "tutorial mancanti"

echo "== 8. File launcher Windows (CRLF) =="
c=0
for f in INSTALLA.bat AVVIA.bat SPEGNI.bat; do
  [ -f "$f" ] && { file "$f" | grep -q CRLF && c=$((c+1)) || err "$f senza CRLF"; }
done
[ "$c" -ge 3 ] && pass "$c file .bat in formato Windows"

echo "== 9. Test funzionali della GUI =="
python3 tests/test_gui.py || err "test funzionali GUI"

echo "== 10. Integrita' del progetto =="
# 10a: ogni script citato nel Vagrantfile esiste
vmiss=0
for sp in $(grep -oE 'provision/[0-9a-z-]+\.sh' Vagrantfile | sort -u); do
  [ -f "$sp" ] || { echo "  manca: $sp (citato nel Vagrantfile)"; vmiss=1; }
done
[ "$vmiss" = 0 ] && pass "tutti gli script del Vagrantfile esistono" || err "script Vagrantfile mancanti"
# 10b: ogni stack soclab di tools.json ha la cartella compose (tranne wazuh, scaricato a runtime)
smiss=0
for d in targets splunk elk misp thehive webui; do
  [ -f "soc-lab/$d/docker-compose.yml" ] || { echo "  manca: soc-lab/$d/docker-compose.yml"; smiss=1; }
done
[ "$smiss" = 0 ] && pass "tutti gli stack SOC hanno il compose" || err "compose SOC mancanti"
# 10c: i file .desktop hanno Exec= e Name=
dmiss=0
while IFS= read -r d; do
  grep -q '^Exec=' "$d" && grep -q '^Name=' "$d" || { echo "  .desktop incompleto: $d"; dmiss=1; }
done < <(find condivisa -name '*.desktop' 2>/dev/null)
[ "$dmiss" = 0 ] && pass "tutti i launcher .desktop sono validi" || err ".desktop incompleti"
# 10d: ogni scheda della GUI ha il suo tutorial
python3 - <<'PYEOF' && pass "ogni tool della GUI ha il tutorial" || err "tutorial GUI mancanti"
import json,os,sys
d=json.load(open("gui/tools.json"))
tuts=set(os.path.splitext(f)[0] for f in os.listdir("menu/tutorials"))
miss=[t["tut"] for c in d["categories"] for t in c["tools"] if t["tut"] not in tuts]
[print("  manca tutorial GUI:",m) for m in miss]
sys.exit(1 if miss else 0)
PYEOF
# 10e: il binario controllato (bin) coincide col comando lanciato (cmd)
python3 - <<'PYEOF' && pass "bin e comando allineati in tutte le schede GUI" || err "bin/cmd disallineati"
import json,sys
d=json.load(open("gui/tools.json"))
def fb(c):
    p=c.split()
    if p and p[0]=="sudo": p=p[1:]
    return p[0] if p else ""
bad=[(t["bin"],fb(t["cmd"])) for c in d["categories"] for t in c["tools"] if fb(t["cmd"])!=t["bin"]]
[print("  disallineato:",b) for b in bad]
sys.exit(1 if bad else 0)
PYEOF
# 10f: nel menu testuale, il bin coincide col comando
python3 - <<'PYEOF' && pass "bin e comando allineati nel menu testuale" || err "bin/cmd disallineati nel menu"
import re,sys
s=open("menu/cybermenu.sh").read()
rows=re.findall(r'^([a-zA-Z0-9_.-]+)\|([^|]+)\|([^|]+)\|([a-z0-9-]+)$', s, re.M)
def fb(c):
    p=c.split()
    if p and p[0]=="sudo": p=p[1:]
    return p[0] if p else ""
bad=[(b,fb(c)) for b,n,c,t in rows if fb(c)!=b]
[print("  disallineato:",x) for x in bad]
sys.exit(1 if bad else 0)
PYEOF

# 10g: scenari pratici presenti e referenziati in menu e GUI
gmiss=0
for sc in scenario-primo-pentest scenario-soc-analyst scenario-analisi-pcap scenario-active-directory scenario-wireless scenario-forensics-memoria scenario-osint scenario-vuln-assessment; do
  [ -f "menu/tutorials/$sc.md" ] || { echo "  manca scenario: $sc"; gmiss=1; }
  grep -q "$sc" menu/cybermenu.sh || { echo "  scenario non in cybermenu: $sc"; gmiss=1; }
  grep -q "$sc" gui/index.html || { echo "  scenario non in GUI: $sc"; gmiss=1; }
done
[ "$gmiss" = 0 ] && pass "scenari pratici presenti e collegati (menu + GUI)" || err "scenari pratici incompleti"

# 10h: GUI con tema chiaro/scuro
tmiss=0
for k in "toggleTheme" "body.light" "localStorage" 'id="theme"'; do
  grep -q "$k" gui/index.html || { echo "  tema: manca $k"; tmiss=1; }
done
[ "$tmiss" = 0 ] && pass "GUI: tema chiaro/scuro presente e persistente" || err "tema GUI incompleto"

# 10i: configurazione remaster Kali (ISO personalizzata)
imiss=0
for f in kali-iso/build-iso.sh kali-iso/config/package-lists/cybersec.list.chroot          kali-iso/config/hooks/0100-cybersec.hook.chroot          kali-iso/config/autostart/cybergui.desktop          kali-iso/config/firstboot/cybersec-firstboot.sh kali-iso/README.md; do
  [ -f "$f" ] || { echo "  manca: $f"; imiss=1; }
done
bash -n kali-iso/build-iso.sh 2>/dev/null || { echo "  build-iso.sh: sintassi"; imiss=1; }
bash -n kali-iso/config/hooks/0100-cybersec.hook.chroot 2>/dev/null || { echo "  hook: sintassi"; imiss=1; }
grep -q kali-linux-default kali-iso/config/package-lists/cybersec.list.chroot || { echo "  package-list senza metapacchetto"; imiss=1; }
[ "$imiss" = 0 ] && pass "remaster Kali: configurazione ISO completa e valida" || err "config ISO incompleta"

echo ""
if [ "$FAIL" = 0 ]; then echo ">>> TUTTI I TEST SUPERATI <<<"; exit 0
else echo ">>> ALCUNI TEST FALLITI <<<"; exit 1; fi
