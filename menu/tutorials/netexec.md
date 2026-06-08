# NetExec (ex CrackMapExec) - pentest di rete/AD
## Cos'e'
Coltellino svizzero per attaccare reti Windows/Active Directory: enumera,
testa credenziali e si muove lateralmente su SMB, WinRM, LDAP, MSSQL, RDP.
## Uso base
```
netexec smb 10.0.0.0/24                         # enum host SMB
netexec smb 10.0.0.5 -u utente -p password      # test credenziali
netexec smb 10.0.0.5 -u u -p p --shares         # condivisioni
netexec winrm 10.0.0.5 -u u -p p                # accesso WinRM
netexec ldap 10.0.0.5 -u u -p p --users         # utenti dal dominio
```
## Legale
Solo su domini/reti autorizzati.
