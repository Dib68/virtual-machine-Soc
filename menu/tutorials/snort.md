# Snort - Intrusion Detection System
## Uso base
```
sudo snort -V                          # versione
sudo snort -i eth0 -A console -c /etc/snort/snort.conf
sudo snort -r cattura.pcap -c /etc/snort/snort.conf
```
Storico IDS basato su regole. Concetti (regole, signature) molto richiesti
nei colloqui SOC. Alternativa moderna: Suricata.
