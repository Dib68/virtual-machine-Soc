# ClamAV - antivirus open source
## Uso base
```
sudo freshclam                    # aggiorna le firme
clamscan file.exe                 # scansiona un file
clamscan -r --bell -i /home       # scansione ricorsiva (solo infetti)
```
Utile per triage rapido di file sospetti.
