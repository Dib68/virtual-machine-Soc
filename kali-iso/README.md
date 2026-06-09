# CyberSec AI OS — Kali personalizzata attorno al progetto

Questa cartella contiene la configurazione per costruire una **ISO di Kali Linux
personalizzata** ("CyberSec AI OS") in cui il progetto e' **integrato di serie**
e la **GUI Control Center si avvia da sola** a ogni accesso. In pratica una Kali
"remasterizzata" che ruota attorno a questo progetto.

## Cosa la rende diversa da una Kali normale
- Tutti i tool del progetto preinstallati (metapacchetto `kali-linux-default` + extra).
- I comandi `cybergui`, `cybermenu`, `ai`, `soclab`, `cyberdoctor`, ... gia' presenti.
- **La GUI parte automaticamente** al login (autostart in `/etc/skel`).
- **AI locale (Ollama)** preinstallata; il modello viene scaricato al primo avvio
  (serve internet la prima volta) e diventa poi offline.
- Branding del progetto (`/etc/cybersec-release`).

## Come si costruisce (serve un host Linux Debian/Kali)
Requisiti: Debian o Kali, internet, ~20 GB liberi, tempo (30-90 min).
```
sudo bash kali-iso/build-iso.sh
```
Lo script: installa `live-build`, scarica la configurazione ufficiale di Kali,
inietta i pacchetti/hook/file del progetto e costruisce la ISO.
Al termine la trovi in `~/cybersec-iso-build/live-build-config/images/`.

## Come si usa la ISO
1. Scrivi la ISO su una chiavetta USB (es. con balenaEtcher o `dd`) oppure
   creane una VM in VirtualBox e montala come disco di avvio.
2. Avvia: parte Kali e, dopo il login, si apre da sola la GUI del progetto.
3. Al primo avvio l'assistente AI si configura (serve internet una volta).

## Struttura
```
kali-iso/
├── build-iso.sh                      # costruisce la ISO
├── config/
│   ├── package-lists/cybersec.list.chroot   # pacchetti inclusi
│   ├── hooks/0100-cybersec.hook.chroot      # integra il progetto in fase di build
│   ├── autostart/cybergui.desktop           # avvia la GUI a ogni login
│   ├── autostart/cybersec-firstboot.desktop # configura l'AI al primo avvio
│   └── firstboot/cybersec-firstboot.sh      # script del primo avvio
└── README.md
```

## Note
- La build vera dell'ISO non puo' essere eseguita dentro questa cartella di
  sviluppo: richiede un host Linux con `live-build`. La configurazione qui e'
  completa e pronta all'uso.
- Riferimento ufficiale: https://www.kali.org/docs/development/live-build-a-custom-kali-iso/
- Uso esclusivamente didattico / test autorizzati (vedi DISCLAIMER.md).
