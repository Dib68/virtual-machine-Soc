# Cheatsheet rapida - comandi piu' usati

## Comandi della VM
| Comando | Cosa fa |
|---|---|
| `cybermenu` | menu interattivo con tutti i tool e i tutorial |
| `ai` | assistente AI di sicurezza (offline) |
| `ai "domanda"` | risposta singola dell'AI |
| `soclab targets up` | avvia i bersagli vulnerabili (DVWA, Juice Shop, WebGoat) |
| `soclab splunk up` | avvia Splunk (SIEM) |
| `soclab wazuh up` | avvia Wazuh (SIEM+EDR) |
| `soclab status` | container attivi + indirizzi web |

## Recon / scanning
```
nmap -sV -sC -oA scan 10.0.0.0/24
nmap -p- --min-rate 5000 10.0.0.5
subfinder -d target.com -silent | httpx -silent | nuclei
```

## Web
```
gobuster dir -u http://t -w /usr/share/seclists/Discovery/Web-Content/common.txt
sqlmap -u "http://t/p?id=1" --batch --dbs
nikto -h http://t
```

## Password
```
hydra -l admin -P rockyou.txt ssh://10.0.0.5
hashcat -m 0 -a 0 hash.txt rockyou.txt
john --wordlist=rockyou.txt hash.txt
```

## Blue Team / SOC
```
sudo suricata -r cattura.pcap -l ./log     # IDS su pcap
zeek -r cattura.pcap                        # genera log di rete
yara -r regole.yar /percorso                # caccia malware
osqueryi "SELECT name,pid FROM processes;"  # stato endpoint
clamscan -r -i /home                        # antivirus
```

## Cloud / DevSecOps
```
trivy image nginx:latest        # vuln in immagine container
trivy config .                  # misconfig IaC
prowler aws                     # audit AWS
scout aws                       # report HTML cloud
```

## Forensics
```
volatility3 -f mem.raw windows.pslist
binwalk -e firmware.bin
exiftool foto.jpg
```

REGOLA: usa tutto SOLO su sistemi tuoi o autorizzati.
