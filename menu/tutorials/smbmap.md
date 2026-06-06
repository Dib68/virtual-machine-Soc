# SMBMap - enumerazione condivisioni SMB
## Uso base
```
smbmap -H 10.0.0.5
smbmap -H 10.0.0.5 -u utente -p password
smbmap -H 10.0.0.5 -r nome_share          # naviga la share
```
Mostra i permessi (READ/WRITE) sulle condivisioni di rete.
