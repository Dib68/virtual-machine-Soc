# CyberSec AI VM — Macchina virtuale per VirtualBox

VM **Kali Linux** automatizzata con **Vagrant**: un laboratorio completo di
cybersecurity, **Red Team** e **Blue Team / SOC**, con **AI locale integrata**
e **menu interattivo con tutorial** per ogni strumento.

I tool sono scelti in base a cosa chiedono gli HR negli annunci reali — vedi
`JOB-TOOLS.md` e la voce di menu "Tool richiesti dagli annunci di lavoro".

## Cosa include

- **Red Team**: nmap, Metasploit, Burp, ZAP, sqlmap, hydra, hashcat, john,
  Wireshark, aircrack-ng, OSINT (theHarvester, recon-ng, SpiderFoot), forensics
  (Autopsy, Volatility, binwalk), reverse (radare2, Ghidra, gdb).
- **Active Directory / Pentest**: NetExec, Impacket, Responder, Evil-WinRM,
  BloodHound, Kerbrute, enum4linux-ng, SMBMap.
- **CTF / Exploit Dev**: pwntools, ROPgadget, GEF.
- **Threat hunting moderno**: nuclei, httpx, subfinder, naabu, feroxbuster.
- **Blue Team / SOC**: Suricata, Snort, Zeek, YARA, OSQuery, Velociraptor,
  ClamAV, Lynis.
- **Cloud & DevSecOps**: AWS/Azure/GCP CLI, kubectl, Helm, Terraform, Trivy,
  ScoutSuite, Prowler, Checkov.
- **Stack SOC via Docker** (comando `soclab`): Splunk, ELK/Kibana, Wazuh, MISP,
  TheHive+Cortex, OpenWebUI, e bersagli vulnerabili (DVWA, Juice Shop, WebGoat).
- **AI locale** (Ollama + modello `cyberai`): gratuita, offline, nessuna API key.
- **GUI moderna** (`cybergui`): Control Center grafico nel browser con ricerca,
  schede dei tool, AI in chat e controllo degli stack SOC.
- **Menu interattivo** (`cybermenu`) con ~70 tutorial.
- **Utility**: cyberdoctor, ai-explain, cyberreport, cyberupdate.

---

## 1. Prerequisiti (una volta sola)

1. **VirtualBox** → https://www.virtualbox.org/wiki/Downloads
2. **Vagrant** → https://developer.hashicorp.com/vagrant/install
3. (Consigliato) `vagrant plugin install vagrant-disksize`

Risorse host consigliate: **≥ 16 GB RAM** e **≥ 80 GB disco** liberi (la VM usa
10 GB di RAM per far girare l'AI piu' potente; gli stack SIEM come Wazuh sono esigenti).

---

## 2. Installazione con UN clic (come un'app)

**Windows** — fai doppio clic su **`INSTALLA.bat`**.
Fa tutto da solo: chiede i permessi di amministratore, installa VirtualBox e
Vagrant se mancano, scarica e configura la VM, e crea sul Desktop i collegamenti
**AVVIA** e **SPEGNI**. Da quel momento usi la VM come un programma normale:
doppio clic su **AVVIA** per accenderla, **SPEGNI** per spegnerla.

**Linux / macOS** — esegui **`./installa.sh`** (doppio clic o da terminale).

> Nota: serve una connessione a Internet e spazio su disco; il primo avvio
> scarica alcuni GB, quindi richiede tempo. Lascia lavorare l'installer.

---

## 3. (Alternativa) Avvio manuale da terminale

Da un terminale in questa cartella:

```
vagrant up        # oppure:  make up
```

Alla prima esecuzione scarica Kali e installa tutto (alcuni GB, ci vuole tempo).
Poi si apre VirtualBox. **Login:** `vagrant` / `vagrant`.

---

## 4. Comandi nella VM

| Comando | Cosa fa |
|---|---|
| `cybergui` | **GUI moderna** (Control Center) nel browser — consigliata |
| `cybermenu` | Menu interattivo testuale: categorie, tool e tutorial |
| `ai` | Assistente AI di cybersecurity (CyberAI) |
| `ai "..."` | Domanda singola, es. `ai "come uso nmap su una /24?"` |
| `soclab targets up` | Bersagli vulnerabili (DVWA, Juice Shop, WebGoat) |
| `soclab splunk up` | Splunk (SIEM) → http://localhost:8000 |
| `soclab elk up` | ELK/Kibana → http://localhost:5601 |
| `soclab wazuh up` | Wazuh (SIEM+EDR) → https://localhost:443 |
| `soclab misp up` | MISP (threat intel) → https://localhost:8443 |
| `soclab thehive up` | TheHive+Cortex (incident response) |
| `soclab webui up` | OpenWebUI (AI nel browser) → http://localhost:3001 |
| `soclab status` / `soclab stopall` | Stato / ferma tutti gli stack |
| `cyberdoctor` | Diagnostica VM (tool, AI, docker, risorse) |
| `cyberreport pentest` | Template report (o `ir` per incident response) |
| `ai-explain file` | L'AI spiega un file o l'output di un comando (anche via pipe) |
| `cyberupdate` | Aggiorna sistema, database e modelli AI |

Comandi Vagrant (dall'host): `vagrant halt|up|ssh|reload|provision|destroy`
oppure le scorciatoie `make` (vedi `make help`).

---

## 5. Struttura del progetto

```
virtual machine Soc/
├── Vagrantfile              # definizione VM + provider VirtualBox
├── README.md                # questa guida
├── JOB-TOOLS.md             # mappa tool -> ruolo (cosa chiedono gli HR)
├── CHEATSHEET.md            # comandi rapidi piu' usati
├── RISORSE-STUDIO.md        # percorso di studio, certificazioni, piattaforme
├── DISCLAIMER.md            # uso responsabile e note legali
├── CHANGELOG.md / VERSION   # storico versioni
├── Makefile                 # scorciatoie (make up, make ova, ...)
├── build-ova.sh             # genera un .ova distribuibile (via Vagrant)
├── provision/               # 01..09: script di installazione automatica
├── menu/
│   ├── cybermenu.sh  ai.sh  # comandi `cybermenu` e `ai`
│   └── tutorials/           # ~70 tutorial, uno per strumento
├── tools/                   # utility (cyberdoctor, ai-explain, ...)
├── soc-lab/                 # stack Docker (comando `soclab`)
│   ├── soclab.sh
│   └── targets/ splunk/ elk/ misp/ thehive/ webui/
├── tests/                   # suite di test automatici (run-tests.sh)
├── packer/                  # build avanzata dell'.ova da ISO
└── condivisa/               # cartella condivisa host <-> VM (auto)
```

---

## 6. Personalizzazione

- **RAM/CPU**: modifica `vb.memory` e `vb.cpus` nel `Vagrantfile`.
- **Aggiungere un tool**: aggiungilo nello script `provision/` adatto e, per
  vederlo nel menu, aggiungi una riga nella categoria giusta in
  `menu/cybermenu.sh` (più un tutorial in `menu/tutorials/`).
- **Modello AI**: in `provision/02-ollama.sh` cambia `ollama pull ...`
  (modelli più grandi = più bravi ma più RAM).
- Dopo le modifiche: `vagrant provision` (o `make provision`).

---

## 7. Generare un `.ova` distribuibile

**Rapida (consigliata):**
```
./build-ova.sh        # oppure: make ova
```

**Avanzata (build da ISO con Packer):**
```
cd packer && packer init . && packer build cybersec-ai.pkr.hcl
```
(aggiorna prima `iso_url`/`iso_checksum` all'ultima Kali).

Chi riceve l'`.ova` lo importa con *File > Importa applicazione virtuale*.

---

## ⚠️ Avviso legale

Usa questi strumenti **solo** su sistemi tuoi o con **autorizzazione scritta**.
L'uso non autorizzato è un **reato**. I bersagli vulnerabili vanno eseguiti solo
in locale, sulla rete isolata, mai esposti a Internet. Dettagli in `DISCLAIMER.md`.

---

## Test e qualita'

Il progetto include una suite di test automatici (sintassi di tutti gli script,
validita' di JSON/YAML/HCL, coerenza menu-tutorial e test funzionali della GUI):

```
bash tests/run-tests.sh
```

Gli stessi test girano in automatico su ogni push tramite GitHub Actions
(`.github/workflows/ci.yml`).

---

## Fonti / riferimenti

- [Kali Linux — Vagrant (`kalilinux/rolling`)](https://www.kali.org/docs/virtualization/install-vagrant-guest-vm/)
- [Kali Vagrant rebuilt with DebOS](https://www.kali.org/blog/kali-vagrant-rebuilt/)
- [Ollama (AI locale)](https://ollama.com/)
- [SOC Analyst Tools — CyberDefenders](https://cyberdefenders.org/blog/Top-8-soc-analyst-tools/)
- [Open-Source Tools for SOC Analysts](https://www.cyber-defence.io/blog/open-source-tools-for-soc-analysts)
