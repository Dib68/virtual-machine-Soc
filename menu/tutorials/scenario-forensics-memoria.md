# Scenario guidato: analisi forense della memoria (RAM)

Obiettivo: analizzare un dump di memoria con Volatility 3.

## 1. Procurati un dump
Usa un dump di esempio (es. da CTF) oppure acquisiscine uno con strumenti DFIR.
Mettilo in /tmp/mem.raw

## 2. Informazioni generali
```
vol -f /tmp/mem.raw windows.info
```

## 3. Processi e connessioni
```
vol -f /tmp/mem.raw windows.pslist
vol -f /tmp/mem.raw windows.pstree
vol -f /tmp/mem.raw windows.netscan
```

## 4. Cerca codice iniettato / malware
```
vol -f /tmp/mem.raw windows.malfind
```

## 5. Fai riassumere i risultati dall'AI
```
vol -f /tmp/mem.raw windows.pslist | ai-explain
```
