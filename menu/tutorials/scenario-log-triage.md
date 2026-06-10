# Scenario guidato: triage dei log e caccia alle minacce

Obiettivo: dato un insieme di log, individuare attivita' sospette e produrre
indicatori (IOC). Adatto al ruolo di SOC Analyst.

## 1. Prima occhiata ai log di autenticazione
```
grep -i "failed password" /var/log/auth.log | awk '{print $(NF-3)}' | sort | uniq -c | sort -rn | head
# IP con piu' tentativi falliti (possibile brute force)
```

## 2. Accessi riusciti sospetti
```
grep -i "Accepted password" /var/log/auth.log | tail -20
last -ai | head
```

## 3. Analisi di log web (Apache/Nginx)
```
awk '{print $1}' access.log | sort | uniq -c | sort -rn | head     # top IP
grep -iE "union|select|\.\./|<script" access.log                   # pattern di attacco
awk '$9 ~ /^(4|5)/{print $7}' access.log | sort | uniq -c | sort -rn | head  # errori 4xx/5xx
```

## 4. Correlazione con SIEM
- Carica i log in uno stack del SOC Lab: `soclab splunk up` oppure `soclab elk up`.
- Cerca per IP/utente sospetti e costruisci una timeline.

## 5. Arricchimento e IOC
- Estrai IP, domini e hash sospetti e annotali come IOC.
- Mappa le tecniche osservate su MITRE ATT&CK.

## 6. Report
```
cyberreport ir        # crea il template di incident response
```

## Note
- Usa il pulsante "Analizza output" della GUI o `ai-explain` per interpretare i log.
- Conserva i log originali (catena di custodia) prima di filtrarli.
