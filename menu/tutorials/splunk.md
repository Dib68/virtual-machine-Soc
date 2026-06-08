# Splunk - il SIEM piu' richiesto
## Cos'e'
Piattaforma SIEM leader di mercato: raccoglie log e li interroga con il
linguaggio SPL. "Esperienza SIEM" e' la skill #1 negli annunci SOC.
## In questa VM
```
soclab splunk up      # avvia Splunk Free in Docker -> http://localhost:8000
```
Login: admin / Changeme123!
## Ricerche SPL di base
```
index=* | head 20
index=main sourcetype=access_combined status=500
... | stats count by src_ip | sort -count
```
