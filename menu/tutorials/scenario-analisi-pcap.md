# Scenario guidato: analisi di una cattura di rete (pcap)

Obiettivo: catturare traffico e analizzarlo come in un'indagine.

## 1. Cattura il traffico
```
sudo tcpdump -i eth0 -w /tmp/cattura.pcap     # CTRL+C per fermare
```

## 2. Apri con Wireshark
```
wireshark /tmp/cattura.pcap
```
Filtri utili: `http`, `dns`, `ip.addr == X.X.X.X`, `tcp.port == 443`.
Tasto destro su un pacchetto -> Follow > TCP Stream.

## 3. Estrai informazioni con Zeek
```
zeek -r /tmp/cattura.pcap
cat conn.log | zeek-cut id.orig_h id.resp_h service
cat dns.log  | zeek-cut query | sort -u
```

## 4. Passa l'output all'AI per un riassunto
```
zeek-cut id.orig_h id.resp_h service < conn.log | ai-explain
```
