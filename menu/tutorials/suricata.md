# Suricata - IDS/IPS e Network Security Monitoring
## Cos'e'
Motore di rilevamento intrusioni ad alte prestazioni: analizza il traffico
con regole/firme e genera alert. Tra i tool piu' citati per ruoli SOC.
## Uso base
```
sudo suricata --build-info            # verifica funzionalita'
sudo suricata -i eth0                  # live su interfaccia
sudo suricata -r cattura.pcap -l ./log # analizza un pcap
sudo suricata-update                   # aggiorna le regole (ET Open)
```
Gli alert finiscono in `/var/log/suricata/fast.log` e `eve.json` (JSON,
ideale da inviare a un SIEM come ELK/Splunk).
