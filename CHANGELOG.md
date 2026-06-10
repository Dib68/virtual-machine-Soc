# Changelog

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
