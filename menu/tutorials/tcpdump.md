# tcpdump - sniffer da terminale

## Uso base
```
sudo tcpdump -i eth0
sudo tcpdump -i eth0 port 80 -w cattura.pcap   # salva su file
sudo tcpdump -i eth0 host 192.168.1.10
```
Apri poi il .pcap con Wireshark per l'analisi grafica.
