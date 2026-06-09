# Scenario guidato: indagine OSINT su un dominio

Obiettivo: raccogliere informazioni pubbliche su un dominio autorizzato.

## 1. Email e sottodomini
```
theHarvester -d esempio.com -b all
subfinder -d esempio.com -silent
```

## 2. Host vivi e tecnologie
```
subfinder -d esempio.com -silent | httpx -silent -title -tech-detect -status-code
```

## 3. OSINT automatico con SpiderFoot
```
spiderfoot -l 127.0.0.1:5001
```
Apri http://127.0.0.1:5001 e avvia una scansione sul dominio.

## 4. Metadati dei documenti pubblici
```
exiftool documento.pdf      # nomi utente, software, date
```

## Nota
Raccogli solo informazioni pubbliche e per scopi legittimi/autorizzati.
