# Tool richiesti dagli HR negli annunci di cybersecurity

Sintesi della ricerca sugli annunci (SOC, pentest, cloud, DevSecOps).
Per ogni tool e' indicato se e' presente/avviabile in questa VM.

## SIEM (skill #1 per i SOC - "esperienza SIEM" richiesta nel ~94% degli annunci)
- Splunk ............ SI (soclab splunk up)  -> leader di mercato
- Wazuh (SIEM+EDR) .. SI (soclab wazuh up)   -> gratuito, sul CV vale molto
- Elastic / ELK ..... avviabile via Docker
- Microsoft Sentinel / QRadar . cloud/commerciali (solo concetti)

## EDR / Endpoint
- Wazuh, OSQuery, Velociraptor ... SI (installati)
- CrowdStrike / SentinelOne / Defender ... commerciali (concetti)

## IDS / Network Security Monitoring
- Suricata, Snort, Zeek ........... SI (installati)

## Threat Intelligence & Incident Response
- MISP (IOC sharing) ............... via Docker
- TheHive + Cortex (SIRP) .......... via Docker
- MITRE ATT&CK (framework) ......... vedi tutorial 'mitre-attack'

## Vulnerability Assessment
- Nessus .......................... installabile (tutorial 'nessus')
- OpenVAS / Greenbone ............. SI (installato)

## Penetration Testing (red team)
- Nmap, Metasploit, Burp Suite, OWASP ZAP, sqlmap, Hydra, John,
  Hashcat, Wireshark, Aircrack-ng ... SI (tutti installati)
- Nuclei, httpx, subfinder, naabu, feroxbuster ... SI (threat hunting moderno)

## Cloud Security
- AWS CLI, Azure CLI, gcloud ...... SI
- ScoutSuite, Prowler (audit) ..... SI
- IAM: concetto chiave in ogni annuncio cloud

## DevSecOps / Container / IaC
- Docker, Kubernetes (kubectl), Helm, Terraform ... SI
- Trivy, Checkov (scanner IaC/container) .......... SI
- kube-bench / kube-hunter ........................ via Docker

## Forensics / DFIR
- Autopsy, Sleuth Kit, Volatility3, binwalk, ExifTool, YARA,
  Velociraptor, OSQuery ............ SI

## Scripting (richiesto quasi ovunque)
- Python3, Bash ................... SI
- PowerShell (pwsh) ............... SI

## Ticketing / ITSM (solo conoscenza)
- ServiceNow, Jira ................ usati nei SOC reali (non installabili qui)

## Certificazioni spesso citate
- CompTIA Security+, CySA+, eJPT, OSCP, BTL1, CEH, AZ-500, AWS Security.

---
NOTA: i tool commerciali (Splunk Enterprise, CrowdStrike, Nessus Pro, QRadar,
Sentinel) sono a pagamento; qui usiamo le versioni gratuite o gli equivalenti
open source che coprono le STESSE competenze richieste dagli annunci.
