# Changelog

## 2.42.0
- **Conteggi coerenti nella dashboard**: prima "installati" e "mancanti (N)" non
  tornavano col totale, perche' "mancanti" contava solo i tool installabili via apt
  (i 4 non-apt sparivano). Ora la metrica "Mancanti" = totale - installati e il
  pulsante dice "Installa N mancanti (via apt)", segnalando quanti richiedono
  COMPLETA-INSTALLAZIONE. Tutto riconcilia col totale.

## 2.41.0
- **DNS affidabile nella VM** (`natdnshostresolver` in Vagrantfile): risolve gli
  errori intermittenti "Temporary failure resolving" che facevano fallire apt e
  quindi il provisioning (AI, docker, tool) in silenzio. Causa radice dei problemi.

## 2.40.0
- **06-soclab installa il motore Docker** (`docker.io`), non solo la CLI: senza il
  daemon gli stack SOC non partivano.

## 2.39.0
- **COMPLETA-INSTALLAZIONE** ora applica anche il **branding "CyberSec AI OS"** e la
  **verifica finale** (prima un'installazione completa restava senza branding custom).
- L'installer one-click e il suo lanciatore sono ora **versionati** (erano esclusi
  dal `.gitignore` per errore).

## 2.38.0
- **Verifica finale del provisioning** (`provision/11-verify.sh`, ultimo step):
  controlla tool chiave, AI e Docker e, se manca qualcosa, lo segnala chiaramente
  e lascia un marcatore (`/opt/cybersec/provision_incomplete`) con le istruzioni.
  `cyberdoctor` lo riporta. Evita installazioni parziali "invisibili" come quella
  che aveva lasciato l'AI non installata.

## 2.37.0
- **Modello AI tenuto caldo** in RAM (`OLLAMA_KEEP_ALIVE=30m`): le risposte
  successive alla prima sono molto piu' rapide.

## 2.36.0
- `ai-explain` reso robusto: verifica che Ollama sia installato (altrimenti indica
  come installarlo) e avvia il servizio da solo se non risponde.

## 2.35.0
- Pallino "AI" nell'header cliccabile: apre la chat se pronta, altrimenti avvia
  Installa/Ripara AI.

## 2.34.0
- **Pulsante "Installa/Ripara AI"** nella chat: quando l'AI non e' pronta, un clic
  installa/ripara Ollama e il modello mostrando l'avanzamento in tempo reale
  (endpoint `/api/ai_setup_stream`). Niente piu' "AI non attivata" senza via d'uscita.
- `setup-inside-vm` copia gli script di provisioning in `/opt/cybersec/provision`.

## 2.33.0
- **Installazione AI robusta**: `02-ollama.sh` ora scarica il modello con piu'
  tentativi e verifica, crea `cyberai` controllando l'esito (senza nascondere gli
  errori) e, se fallisce, lascia un marcatore e istruzioni chiare invece di
  fallire in silenzio. `cyberdoctor` rileva il problema e indica come riparare.
  Questo era il motivo per cui l'AI poteva risultare "non attivata".

## 2.32.0
- **Login senza sovrapposizioni**: il blocco "CyberSec AI OS" e' stato spostato in
  alto e centrato nel wallpaper, cosi' il riquadro delle credenziali (al centro)
  non lo copre piu'.
- **Messaggio AI piu' chiaro**: se Ollama non e' installato, la chat lo segnala e
  indica il comando per installarlo (`sudo bash /vagrant/provision/02-ollama.sh`).

## 2.31.0
- **Branding centrato**: il blocco "CyberSec AI OS" del wallpaper (visibile anche
  nella schermata di login) ora e' perfettamente centrato. Il testo prima partiva
  da meta' schermo, spostando il blocco a destra; ridisegnato come stack verticale
  centrato e PNG rigenerato. Riquadro di login anch'esso centrato (50%).

## 2.30.0
- **Schermata di login personalizzata**: il greeter di lightdm usa il tuo sfondo e
  il tuo logo come avatar; niente piu' branding Kali alla richiesta di
  username/password.
- **Menu GRUB brandizzato**: `GRUB_DISTRIBUTOR="CyberSec AI OS"`.

## 2.29.0
- **Splash di avvio con il tuo logo**: lo splash Plymouth "CyberSec AI OS" ora viene
  effettivamente mostrato al boot (abilitato `splash` nella cmdline GRUB +
  `update-grub` + rigenerazione initramfs). Prima il tema era impostato ma non
  appariva perche' mancava `splash`.
- **status() con timeout su Docker**: `docker info` non puo' piu' bloccare lo stato
  della GUI (timeout 4s).

## 2.28.0
- **Feedback "AI in avvio"**: al primo messaggio la chat mostra "Avvio dell'AI in
  corso…" mentre Ollama si avvia, invece di sembrare bloccata.
- **Logo come icona**: il logo del progetto diventa l'icona della finestra app e
  del launcher (Desktop e autostart).

## 2.27.0
- **Server GUI gestito da systemd** (`cybergui.service`): parte automaticamente al
  boot, indipendente dal login, e si riavvia in caso di errore. Risolve il caso in
  cui l'autostart del desktop avviava il server come figlio della sessione e veniva
  terminato (finestra aperta ma server non raggiungibile). L'autostart del desktop
  ora apre solo la finestra app, trovando il server gia' pronto.

## 2.26.0
- **Autostart GUI affidabile**: due voci di avvio distinte (server della GUI +
  finestra app), e `cybergui-app` ora attende che il server risponda (controllo
  via `/dev/tcp`, niente dipendenza da curl) prima di aprire la finestra. Risolve
  il caso in cui all'avvio la finestra partiva prima del server.

## 2.25.0
- **L'AI si avvia da sola**: quando scrivi qualcosa in chat, se il servizio Ollama
  non e' attivo viene avviato automaticamente (`systemctl start ollama` o
  `ollama serve`), senza dover lanciare nulla a mano.

## 2.24.0
- **Kali "CyberSec AI OS"**: branding applicato anche alla VM (nome OS, sfondo,
  MOTD e splash Plymouth quando disponibile) tramite `provision/10-branding-kiosk.sh`.
- **GUI in finestra app dedicata** (non una scheda di Firefox): nuovo launcher
  `cybergui-app` che apre il Control Center con Chromium in modalita' `--app`
  (chromeless), con fallback a Firefox kiosk.
- **Apertura automatica della GUI al login** (autostart nella finestra dedicata);
  l'icona sul Desktop usa la finestra app.
- Il file `VERSION` viene ora installato in `/opt/cybersec/` (l'header mostra la
  versione corretta invece di "?"). Nuova sezione di test 22.

## 2.23.0
- **Fix installazione tool**: "Installa i mancanti" ora installa i pacchetti
  **uno alla volta**, saltando quelli non disponibili via apt (prima un solo nome
  inesistente faceva fallire l'intero blocco senza installare nulla). Riepilogo
  finale con installati/saltati.
- Corretti i metadati: `volatility3`, `kerbrute`, `ROPgadget`, `osquery` non sono
  pacchetti apt (si installano via pip/go/repo dal provisioning) e non vengono
  piu' tentati con apt.

## 2.22.0
- Il comando **`ai` accetta le opzioni `--model` e `--persona`** (Red/Blue Team,
  "spiega semplice"), in parita' con la GUI; `ai --help` mostra l'uso.
- **Suite di test piu' pulita**: i controlli che richiedono un terminale reale
  vengono SALTATI (non falliti) quando `bash` non e' funzionante nell'ambiente
  (es. Windows senza WSL), restando attivi su Linux/CI. Ora la suite passa
  interamente in locale.

## 2.21.0
- **Stato dei lab SOC nella GUI**: ogni stack mostra un badge "attivo/spento" in
  base ai container Docker in esecuzione (endpoint `/api/soclab_status`),
  aggiornato dopo avvio/arresto.
- Nuovi test backend e d'integrazione + sezione 21.

## 2.20.0
- **Evidenziazione sintassi piu' ricca** nei blocchi di comando: oltre a commenti
  e flag, ora colora anche stringhe tra apici e indirizzi IP/CIDR.
- **Pannello "Scorciatoie e aiuto"** nella GUI (pulsante "?" o tasto `?`).
- Nuovo comando **`cyberhelp`**: elenca tutti i comandi della VM con descrizione;
  installato dal provisioning e da setup-inside-vm.
- Test piu' robusti: i controlli sugli script temporanei usano la data di
  modifica (eliminata una possibile flakiness della CI). Nuova sezione 20.

## 2.19.0
- **Sicurezza GUI**: difesa da **DNS-rebinding** (accetta solo richieste con Host
  locale, qualsiasi porta -> altrimenti 403) e header **X-Content-Type-Options:
  nosniff** su tutte le risposte. Il server resta in ascolto solo su 127.0.0.1.
- Nuovi test d'integrazione di sicurezza (Host non locale, header) e controlli
  statici nella suite.

## 2.18.0
- **3 nuove guide pratiche** passo-passo: analisi di un file sospetto (malware),
  test di sicurezza di una API REST, triage dei log e threat hunting. Collegate
  sia al menu testuale sia alla GUI e coperte dai test.

## 2.17.0
- **Avanzamento installazione in tempo reale**: "Installa i mancanti" ora mostra
  l'output di apt in un pannello live nel browser (endpoint
  `/api/install_missing_stream`), con fallback al terminale.
- Nuovi test backend e d'integrazione per l'installazione in streaming.

## 2.16.0
- **Preferiti**: aggiungi gli strumenti ai preferiti con la stella; nuova sezione
  "Preferiti" nel menu, persistente tra i riavvii.
- **Analizza output**: incolla l'output di un comando e fattelo spiegare dall'AI.
- **Hardening del backend**: limite alla lunghezza del prompt/cronologia
  (`MAX_PROMPT`) e al corpo della richiesta (`MAX_BODY`); risposta `400` ai JSON
  malformati invece di andare in errore.
- Nuove sezioni di test 19 + test backend e d'integrazione (JSON malformato).

## 2.15.0
- **Ricerca dentro la chat**: filtra ed evidenzia i messaggi della conversazione.
- **Rinomina conversazione** e **copia singola risposta** (al passaggio del mouse).
- La **ricerca globale** in alto ora trova anche le **guide pratiche** (scenari),
  non solo gli strumenti.
- Nuova sezione di test 18.

## 2.14.0
- **Installazione automatica in blocco**: nuovo pulsante "Installa i mancanti (N)"
  nella dashboard e nelle viste degli strumenti, che installa con un solo clic
  tutti i pacchetti apt non ancora presenti (endpoint `/api/install_missing`).
- Lo stato (`/api/status`) ora riporta quanti strumenti mancano (`missing`).
- Nuova sezione di test 17 + test backend per `missing_pkgs` e `install_missing`.

## 2.13.0
- **Modalita' dell'assistente** (persona): Generale / Red Team / Blue Team-SOC /
  "spiega semplice"; orienta le risposte aggiungendo un'istruzione di sistema.
- **Conversazioni multiple** salvate: crea, cambia ed elimina conversazioni, ognuna
  persistente con titolo automatico (migra la chat singola precedente).
- **Rigenera** l'ultima risposta dell'AI con un clic.
- **Copia comando** direttamente dalle schede degli strumenti.
- **Filtro "solo installati"** nelle viste "Tutti gli strumenti" e per categoria.
- `cyberreport` aggiunge il template **web** (OWASP Top 10).
- Nuova sezione di test 16; nuovi test backend per persona e modello.

## 2.12.0
- **Scelta del modello AI** dalla GUI (automatico / cyberai / llama3.2 e altri
  presenti su Ollama); il modello scelto viene inoltrato al backend.
- **Domande rapide** (chip) nell'assistente AI per partire subito su temi comuni
  (nmap, sqlmap, hashcat, PCAP, privesc, SMB/AD).
- **Esporta conversazione** in Markdown con un clic.
- **Evidenziazione della sintassi** nei blocchi di comando (commenti e flag).
- **Scorciatoie da tastiera**: `Esc` chiude finestre/menu, `/` mette a fuoco la
  ricerca.
- **Versione mostrata** nell'header; nuovo endpoint **`/api/health`** e modelli
  disponibili esposti in `/api/status`.
- `cyberdoctor` ora controlla anche **connettivita', spazio su disco e stato
  della GUI**; il comando `ai` accetta input da **pipe** (es. `cat log | ai`).
- Nuove sezioni di test 14 e 15; `/api/health` coperto dal test d'integrazione.

## 2.11.0
- **AI in streaming**: le risposte compaiono parola per parola (nuovo endpoint
  `/api/ai_stream` + lettura `ReadableStream` nella GUI), con **pulsante Stop**
  per interrompere e fallback automatico all'endpoint non-streaming.
- **Conversazione persistente**: la chat sopravvive al ricaricamento della pagina
  (localStorage); "Pulisci" la azzera anche dal salvataggio.
- **Pulsante "Copia"** su ogni blocco di codice (chat e tutorial).
- **Server multi-thread**: una risposta AI lunga non blocca piu' le altre
  richieste (stato, avvio tool, tutorial). Host Ollama configurabile via
  `OLLAMA_HOST`.
- Nuovo test d'integrazione HTTP (`tests/test_stream.py`) che verifica streaming
  reale e concorrenza; nuove sezioni 12 e 13 nella suite.

## 2.10.0
- **AI con memoria conversazionale**: la chat (GUI e backend) ora usa l'endpoint
  `/api/chat` di Ollama e inoltra la cronologia, quindi CyberAI ricorda le domande
  precedenti e si possono fare domande di seguito. Risposte AI renderizzate in
  markdown (blocchi di codice formattati) e nuovo pulsante "Pulisci".
- Selezione modello AI piu' ricca per RAM: >=28GB qwen2.5:14b, >=7GB qwen2.5:7b,
  altrimenti llama3.2; contesto ampliato a 8192 token.
- Robustezza GUI: avvio dei processi senza dipendere da `setsid` (fallback a
  `start_new_session`), percorso temporaneo portabile (`tempfile.gettempdir()`),
  host Ollama configurabile via `OLLAMA_HOST`.
- `cyberdoctor` verifica anche la presenza del modello `cyberai`.
- Test: nuovi casi per memoria conversazionale e costruzione messaggi; suite resa
  portabile (separatore PATH, temp dir, stub per Windows) e nuova sezione 11.

## 2.2.0
- Launcher GUI robusto (prova qterminal/xfce4-terminal/x-terminal-emulator/gnome-terminal/xterm/konsole).
- Avvio app grafiche in background anche dal menu testuale.
- Suite di test automatici (tests/run-tests.sh + test_gui.py) e CI GitHub Actions.
- Script 'COMPLETA-INSTALLAZIONE' one-click per installare tutto dentro la VM.
- Hardening: dipendenze GUI garantite (python3, curl, terminale); pulizia file temporanei.

## 2.1.0
- Aggiunta GUI moderna "Control Center" (cybergui): dashboard nel browser,
  schede dei tool con Avvia/Guida/AI, ricerca, AI in chat, controllo SOC lab.
- Backend Python (stdlib) + frontend dark responsivo; icona sul Desktop.

## 2.0.0
- Aggiunto profilo Blue Team / SOC: Suricata, Snort, Zeek, YARA, OSQuery,
  Velociraptor, ClamAV, Lynis.
- Stack SOC via Docker (comando `soclab`): Splunk, ELK, Wazuh, MISP,
  TheHive+Cortex, OpenWebUI, bersagli vulnerabili (DVWA/JuiceShop/WebGoat).
- Aggiunto Active Directory / Pentest: NetExec, Impacket, Responder,
  Evil-WinRM, BloodHound, Kerbrute, enum4linux-ng, SMBMap.
- Aggiunto CTF / Exploit Dev: pwntools, ROPgadget, GEF.
- Cloud & DevSecOps: AWS/Azure/GCP CLI, kubectl, Helm, Terraform, Trivy,
  ScoutSuite, Prowler, Checkov.
- Threat hunting moderno: nuclei, httpx, subfinder, naabu, feroxbuster.
- Utility: cyberdoctor, ai-explain, cyberreport, cyberupdate.
- Generazione .ova: build-ova.sh + template Packer.
- Rete privata host-only isolata per il lab.
- Documentazione: JOB-TOOLS, CHEATSHEET, RISORSE-STUDIO, DISCLAIMER, Makefile.
- ~70 tutorial, uno per strumento.

## 1.0.0
- VM Kali base con Vagrant, AI locale (Ollama), menu interattivo e tutorial,
  tool core red team.
