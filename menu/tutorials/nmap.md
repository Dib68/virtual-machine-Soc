# Nmap - Network Mapper

## Cos'e'
Lo scanner di rete piu' usato al mondo: scopre host attivi, porte aperte,
servizi e sistemi operativi. Presente in quasi ogni annuncio di lavoro.

## Uso base
```
nmap 192.168.1.0/24          # scansione di tutta la sottorete
nmap -sV 192.168.1.10        # rileva versioni dei servizi
nmap -p- 192.168.1.10        # tutte le 65535 porte
nmap -A 192.168.1.10         # OS + versioni + script + traceroute
nmap -sS -T4 192.168.1.10    # SYN scan (veloce, richiede sudo)
nmap --script vuln 10.0.0.5  # cerca vulnerabilita' note (NSE)
```

## Consigli
- `-T0..-T5` regola la velocita' (T4 buon compromesso).
- Salva l'output: `-oN report.txt` (testo) o `-oA report` (tutti i formati).

## Legale
Scansiona solo reti/host autorizzati.
