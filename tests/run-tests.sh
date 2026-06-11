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
for sc in scenario-primo-pentest scenario-soc-analyst scenario-analisi-pcap scenario-active-directory scenario-wireless scenario-forensics-memoria scenario-osint scenario-vuln-assessment scenario-malware-analysis scenario-web-api scenario-log-triage; do
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
for f in kali-iso/config/cybergui-kiosk.sh kali-iso/config/branding/wallpaper.png kali-iso/config/branding/motd kali-iso/config/branding/xfce/xfce4-desktop.xml; do
  [ -f "$f" ] || { echo "  manca (branding/kiosk): $f"; imiss=1; }
done
bash -n kali-iso/config/cybergui-kiosk.sh 2>/dev/null || { echo "  cybergui-kiosk: sintassi"; imiss=1; }
grep -q "CyberSec AI OS" kali-iso/config/hooks/0100-cybersec.hook.chroot || { echo "  hook senza branding"; imiss=1; }
for f in kali-iso/config/branding/logo.png kali-iso/config/branding/logo.ico \
         kali-iso/config/branding/plymouth/cybersec/cybersec.plymouth \
         kali-iso/config/branding/plymouth/cybersec/cybersec.script \
         kali-iso/config/branding/plymouth/cybersec/logo.png gui/favicon.png; do
  [ -f "$f" ] || { echo "  manca (logo/splash): $f"; imiss=1; }
done
grep -q "plymouth" kali-iso/config/hooks/0100-cybersec.hook.chroot || { echo "  hook senza plymouth"; imiss=1; }
grep -q "favicon" gui/index.html || { echo "  GUI senza favicon"; imiss=1; }
[ "$imiss" = 0 ] && pass "remaster Kali: configurazione ISO completa e valida" || err "config ISO incompleta"

echo "== 11. AI con memoria conversazionale =="
amiss=0
grep -q "/api/chat" gui/server.py            || { echo "  server.py non usa /api/chat"; amiss=1; }
grep -q "def ai_ask" gui/server.py && grep -q "history" gui/server.py || { echo "  ai_ask senza cronologia"; amiss=1; }
grep -q "history:hist" gui/index.html        || { echo "  la GUI non invia la cronologia"; amiss=1; }
grep -q "function clearChat" gui/index.html  || { echo "  manca il pulsante Pulisci chat"; amiss=1; }
grep -q "num_ctx 8192" provision/02-ollama.sh || { echo "  contesto AI non ampliato"; amiss=1; }
grep -q "def _ensure_ollama" gui/server.py    || { echo "  AI non si avvia da sola (manca _ensure_ollama)"; amiss=1; }
grep -q "_ensure_ollama()" gui/server.py      || { echo "  _ensure_ollama non richiamato in ai_stream"; amiss=1; }
grep -q "def ai_setup_stream" gui/server.py   || { echo "  manca ai_setup_stream (installa/ripara AI)"; amiss=1; }
grep -q "/api/ai_setup_stream" gui/server.py && grep -q "function setupAI" gui/index.html || { echo "  manca il pulsante Installa/Ripara AI"; amiss=1; }
[ "$amiss" = 0 ] && pass "AI: memoria + avvio automatico + installa/ripara (backend + GUI)" || err "AI memoria incompleta"

echo "== 12. AI streaming, persistenza e copia =="
smiss=0
grep -q "def ai_stream" gui/server.py              || { echo "  server.py senza ai_stream"; smiss=1; }
grep -q "/api/ai_stream" gui/server.py             || { echo "  manca endpoint /api/ai_stream"; smiss=1; }
grep -q '"stream": True' gui/server.py             || { echo "  stream non abilitato verso Ollama"; smiss=1; }
grep -q "/api/ai_stream" gui/index.html            || { echo "  la GUI non usa lo streaming"; smiss=1; }
grep -q "getReader" gui/index.html                 || { echo "  la GUI non legge lo stream"; smiss=1; }
grep -q "function stopAI" gui/index.html           || { echo "  manca il pulsante Stop"; smiss=1; }
grep -q "AbortController" gui/index.html           || { echo "  streaming non interrompibile"; smiss=1; }
grep -q "function saveChat" gui/index.html && grep -q "cyberchat" gui/index.html || { echo "  conversazione non persistente"; smiss=1; }
grep -q "function copyCode" gui/index.html         || { echo "  manca Copia sui blocchi di codice"; smiss=1; }
grep -q "ThreadingMixIn" gui/server.py             || { echo "  server non multi-thread"; smiss=1; }
[ "$smiss" = 0 ] && pass "AI: streaming + persistenza + copia (backend + GUI)" || err "AI streaming/UX incompleti"

echo "== 13. Test d'integrazione streaming (HTTP reale, multi-thread) =="
python3 tests/test_stream.py || err "test integrazione streaming"

echo "== 14. Extra GUI: modello, chip, export, scorciatoie, versione =="
xmiss=0
grep -q "/api/health" gui/server.py        || { echo "  manca endpoint /api/health"; xmiss=1; }
grep -q "def ai_models" gui/server.py       || { echo "  manca ai_models (modelli disponibili)"; xmiss=1; }
grep -q '"version"' gui/server.py           || { echo "  status senza versione"; xmiss=1; }
grep -q "def _model_order" gui/server.py    || { echo "  manca scelta del modello (backend)"; xmiss=1; }
grep -q 'id="aimodel"' gui/index.html       || { echo "  manca il selettore modello"; xmiss=1; }
grep -q "function buildChips" gui/index.html || { echo "  mancano le chip rapide"; xmiss=1; }
grep -q "function exportChat" gui/index.html || { echo "  manca l'export della chat"; xmiss=1; }
grep -q "model:AIMODEL" gui/index.html      || { echo "  la GUI non invia il modello scelto"; xmiss=1; }
grep -q "function hl(" gui/index.html        || { echo "  manca l'evidenziazione sintassi"; xmiss=1; }
grep -q "e.key==='Escape'" gui/index.html   || { echo "  mancano le scorciatoie da tastiera"; xmiss=1; }
grep -q 'id="ver"' gui/index.html           || { echo "  versione non mostrata in GUI"; xmiss=1; }
[ "$xmiss" = 0 ] && pass "GUI extra: modello/chip/export/scorciatoie/versione presenti" || err "GUI extra incompleti"

echo "== 15. cyberdoctor & CLI ai (pipe) =="
cmiss=0
grep -q "Rete & risorse" tools/cyberdoctor.sh || { echo "  cyberdoctor senza check rete/risorse"; cmiss=1; }
grep -q "cybergui" tools/cyberdoctor.sh        || { echo "  cyberdoctor non verifica la GUI"; cmiss=1; }
grep -q "cyberai" tools/cyberdoctor.sh         || { echo "  cyberdoctor non verifica il modello"; cmiss=1; }
grep -q '! -t 0' menu/ai.sh                    || { echo "  'ai' non legge da pipe (stdin)"; cmiss=1; }
grep -q -- '--persona' menu/ai.sh              || { echo "  'ai' senza opzione --persona"; cmiss=1; }
grep -q -- '--model' menu/ai.sh                || { echo "  'ai' senza opzione --model"; cmiss=1; }
[ -f provision/11-verify.sh ] && grep -q "11-verify.sh" Vagrantfile || { echo "  manca la verifica finale del provisioning"; cmiss=1; }
grep -q "provision_incomplete" tools/cyberdoctor.sh || { echo "  cyberdoctor non rileva provisioning incompleto"; cmiss=1; }
[ "$cmiss" = 0 ] && pass "cyberdoctor esteso, CLI 'ai', verifica finale provisioning" || err "cyberdoctor/CLI incompleti"

echo "== 16. AI: persona, conversazioni multiple, rigenera, copia comando =="
pmiss=0
grep -q "PERSONAS" gui/server.py              || { echo "  backend senza modalita' (persona)"; pmiss=1; }
grep -q "persona" gui/server.py               || { echo "  handler senza persona"; pmiss=1; }
grep -q 'id="aipersona"' gui/index.html       || { echo "  GUI senza selettore modalita'"; pmiss=1; }
grep -q "function newConv" gui/index.html && grep -q "cyberconvs" gui/index.html || { echo "  conversazioni multiple assenti"; pmiss=1; }
grep -q "function switchConv" gui/index.html  || { echo "  manca il cambio conversazione"; pmiss=1; }
grep -q "function regenAI" gui/index.html     || { echo "  manca Rigenera"; pmiss=1; }
grep -q "function copyCmd" gui/index.html     || { echo "  manca Copia comando dalle schede"; pmiss=1; }
grep -q "function toggleInst" gui/index.html && grep -q "ONLYINST" gui/index.html || { echo "  manca il filtro Solo installati"; pmiss=1; }
grep -q "OWASP Top 10" tools/cyberreport.sh   || { echo "  cyberreport senza template web/OWASP"; pmiss=1; }
[ "$pmiss" = 0 ] && pass "AI: persona/conversazioni/rigenera/copia + report web" || err "extra avanzati incompleti"

echo "== 17. Installazione automatica dei tool mancanti =="
imiss2=0
grep -q "def install_missing" gui/server.py     || { echo "  backend senza install_missing"; imiss2=1; }
grep -q "def missing_pkgs" gui/server.py         || { echo "  backend senza missing_pkgs"; imiss2=1; }
grep -q "/api/install_missing" gui/server.py     || { echo "  manca endpoint /api/install_missing"; imiss2=1; }
grep -q '"missing"' gui/server.py                || { echo "  status non conta i mancanti"; imiss2=1; }
grep -q "function installMissing" gui/index.html || { echo "  GUI senza pulsante installa-mancanti"; imiss2=1; }
grep -q "/api/install_missing" gui/index.html    || { echo "  GUI non chiama l'endpoint"; imiss2=1; }
grep -q "def install_missing_stream" gui/server.py || { echo "  manca install_missing_stream (progress live)"; imiss2=1; }
grep -q "/api/install_missing_stream" gui/server.py || { echo "  manca endpoint streaming installazione"; imiss2=1; }
grep -q "installlog" gui/index.html              || { echo "  GUI senza pannello di avanzamento"; imiss2=1; }
[ "$imiss2" = 0 ] && pass "installazione automatica dei tool mancanti (backend + GUI + live)" || err "install-missing incompleto"

echo "== 18. Chat: ricerca, rinomina, copia messaggio; ricerca scenari =="
wmiss=0
grep -q "function searchChat" gui/index.html  || { echo "  manca la ricerca nella chat"; wmiss=1; }
grep -q "function hlSearch" gui/index.html     || { echo "  manca l'evidenziazione dei risultati"; wmiss=1; }
grep -q 'id="chatq"' gui/index.html            || { echo "  manca il campo di ricerca chat"; wmiss=1; }
grep -q "function renameConv" gui/index.html   || { echo "  manca la rinomina conversazione"; wmiss=1; }
grep -q "function copyMsgBtn" gui/index.html   || { echo "  manca la copia del singolo messaggio"; wmiss=1; }
grep -q "SCEN.filter" gui/index.html           || { echo "  la ricerca globale non include gli scenari"; wmiss=1; }
[ "$wmiss" = 0 ] && pass "chat: ricerca/rinomina/copia + ricerca scenari" || err "extra chat/ricerca incompleti"

echo "== 19. Preferiti, analizza output e hardening input =="
fmiss=0
grep -q "_host_ok" gui/server.py               || { echo "  backend senza difesa DNS-rebinding (Host)"; fmiss=1; }
grep -q "X-Content-Type-Options" gui/server.py || { echo "  backend senza header anti-sniffing"; fmiss=1; }
grep -q "function toggleFav" gui/index.html && grep -q "cyberfav" gui/index.html || { echo "  manca la gestione preferiti"; fmiss=1; }
grep -q "function favTools" gui/index.html     || { echo "  manca la vista preferiti"; fmiss=1; }
grep -q "function analyzeOutput" gui/index.html || { echo "  manca 'Analizza output'"; fmiss=1; }
grep -q "MAX_PROMPT" gui/server.py             || { echo "  backend senza limite prompt"; fmiss=1; }
grep -q "MAX_BODY" gui/server.py               || { echo "  backend senza limite corpo richiesta"; fmiss=1; }
[ "$fmiss" = 0 ] && pass "preferiti + analizza output + hardening input" || err "preferiti/hardening incompleti"

echo "== 20. Evidenziazione ricca, aiuto e comando cyberhelp =="
hmiss=0
grep -q "c-num" gui/index.html                 || { echo "  evidenziazione IP/numeri assente"; hmiss=1; }
grep -q "function showHelp" gui/index.html      || { echo "  manca il pannello aiuto"; hmiss=1; }
grep -q "e.key==='?'" gui/index.html            || { echo "  manca la scorciatoia '?'"; hmiss=1; }
[ -f tools/cyberhelp.sh ]                       || { echo "  manca lo script cyberhelp"; hmiss=1; }
grep -q "cyberhelp" provision/08-utils.sh && grep -q "cyberhelp" setup-inside-vm.sh || { echo "  cyberhelp non installato dal provisioning"; hmiss=1; }
[ "$hmiss" = 0 ] && pass "evidenziazione ricca + aiuto + cyberhelp" || err "extra UX/cyberhelp incompleti"

echo "== 21. Stato dei lab SOC nella GUI =="
omiss=0
grep -q "def soclab_status" gui/server.py     || { echo "  backend senza soclab_status"; omiss=1; }
grep -q "/api/soclab_status" gui/server.py     || { echo "  manca endpoint /api/soclab_status"; omiss=1; }
grep -q "function loadSocStatus" gui/index.html || { echo "  GUI non mostra lo stato SOC"; omiss=1; }
grep -q "socst-" gui/index.html                || { echo "  manca il badge di stato SOC"; omiss=1; }
[ "$omiss" = 0 ] && pass "stato dei lab SOC (backend + GUI)" || err "stato SOC incompleto"

echo "== 22. Branding custom + GUI in finestra app (kiosk) =="
kmiss=0
[ -f gui/cybergui-app.sh ]                          || { echo "  manca il launcher finestra-app"; kmiss=1; }
grep -q -- '--app=' gui/cybergui-app.sh             || { echo "  cybergui-app non usa la modalita' app"; kmiss=1; }
grep -q "chromium" gui/cybergui-app.sh              || { echo "  cybergui-app senza Chromium"; kmiss=1; }
[ -f provision/10-branding-kiosk.sh ]               || { echo "  manca lo script di branding/kiosk"; kmiss=1; }
grep -q "CyberSec AI OS" provision/10-branding-kiosk.sh || { echo "  branding senza nome OS"; kmiss=1; }
grep -q "cybergui-app" provision/10-branding-kiosk.sh && grep -q "autostart" provision/10-branding-kiosk.sh || { echo "  manca l'autostart della GUI"; kmiss=1; }
grep -q "cybergui.service" provision/10-branding-kiosk.sh && grep -q "systemctl enable" provision/10-branding-kiosk.sh || { echo "  server GUI non gestito da systemd"; kmiss=1; }
grep -q "pixmaps/cybersec.png" provision/10-branding-kiosk.sh || { echo "  logo non usato come icona"; kmiss=1; }
grep -q "Avvio dell" gui/index.html || { echo "  manca il feedback 'AI in avvio'"; kmiss=1; }
grep -q "plymouth-set-default-theme" provision/10-branding-kiosk.sh && grep -q "update-grub" provision/10-branding-kiosk.sh && grep -q "splash" provision/10-branding-kiosk.sh || { echo "  splash di boot (Plymouth/GRUB) non configurato"; kmiss=1; }
grep -q "lightdm-gtk-greeter.conf" provision/10-branding-kiosk.sh || { echo "  schermata di login non personalizzata"; kmiss=1; }
grep -q "GRUB_DISTRIBUTOR" provision/10-branding-kiosk.sh || { echo "  menu GRUB non brandizzato"; kmiss=1; }
grep -q "10-branding-kiosk.sh" Vagrantfile          || { echo "  branding non nel Vagrantfile"; kmiss=1; }
grep -q "cybergui-app" setup-inside-vm.sh           || { echo "  cybergui-app non installato da setup-inside-vm"; kmiss=1; }
bash -n gui/cybergui-app.sh 2>/dev/null             || { echo "  cybergui-app: sintassi"; kmiss=1; }
bash -n provision/10-branding-kiosk.sh 2>/dev/null  || { echo "  10-branding-kiosk: sintassi"; kmiss=1; }
[ "$kmiss" = 0 ] && pass "branding custom + GUI in finestra app + autostart" || err "branding/kiosk incompleto"

echo ""
if [ "$FAIL" = 0 ]; then echo ">>> TUTTI I TEST SUPERATI <<<"; exit 0
else echo ">>> ALCUNI TEST FALLITI <<<"; exit 1; fi
