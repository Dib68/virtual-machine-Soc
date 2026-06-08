# Volatility 3 - analisi della memoria (RAM)

## Uso base
```
vol -f memoria.raw windows.info             # info sul dump
vol -f memoria.raw windows.pslist           # processi
vol -f memoria.raw windows.netscan          # connessioni di rete
vol -f memoria.raw windows.malfind          # codice sospetto/iniettato
```
Analizza dump di memoria per incident response e analisi malware.
