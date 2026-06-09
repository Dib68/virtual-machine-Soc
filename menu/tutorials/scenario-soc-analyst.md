# Scenario guidato: il tuo primo turno da SOC Analyst

Obiettivo: avviare un SIEM, generare traffico/eventi e analizzarli.

## 1. Avvia un SIEM
```
soclab splunk up      # http://localhost:8000  (admin / Changeme123!)
```
(oppure `soclab wazuh up` se hai 10+ GB di RAM)

## 2. Avvia un IDS e genera un alert
```
sudo suricata -i eth0 &        # in ascolto sulla rete
sudo nmap -sS 127.0.0.1        # genera traffico "sospetto"
cat /var/log/suricata/fast.log # guarda gli alert
```

## 3. Analizza un endpoint con OSQuery
```
osqueryi
osquery> SELECT name, pid FROM processes ORDER BY pid DESC LIMIT 10;
osquery> SELECT * FROM listening_ports;
```

## 4. Caccia indicatori con YARA
```
yara -r /opt/cybersec/yara-rules /percorso/sospetto   # se hai delle regole
```

## 5. Apri un caso e documenta
```
cyberreport ir
```
Compila la timeline e gli IOC nel report in ~/reports.
