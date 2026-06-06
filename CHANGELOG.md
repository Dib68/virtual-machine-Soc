# Changelog

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
