# Zeek (ex Bro) - analisi e logging del traffico
## Cos'e'
Non un semplice IDS: produce log ricchi e strutturati (conn.log, dns.log,
http.log, ssl.log...) per analisi e threat hunting.
## Uso base
```
zeek -i eth0                 # cattura live (genera log nella cwd)
zeek -r cattura.pcap         # analizza un pcap
cat conn.log | zeek-cut id.orig_h id.resp_h service
```
