# ELK Stack - Elasticsearch + Kibana (SIEM / analisi log)
## Cos'e'
Stack open source per raccogliere, indicizzare e visualizzare log.
Elastic Security e' tra i SIEM piu' citati negli annunci.
## In questa VM
```
soclab elk up        # avvia ES + Kibana -> http://localhost:5601
```
In Kibana: Discover per esplorare i log, Dashboard per le visualizzazioni,
Security per regole di detection. Invia log con Beats/Logstash/Agent.
