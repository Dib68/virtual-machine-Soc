# Wireshark - analisi del traffico di rete

## Avvio
```
wireshark
```
1. Scegli l'interfaccia (es. eth0) e avvia la cattura.
2. Usa i filtri di visualizzazione, ad esempio:
   - `http`            solo traffico HTTP
   - `ip.addr==1.2.3.4`  traffico da/verso un IP
   - `tcp.port==443`   solo porta 443
3. Tasto destro su un pacchetto -> "Follow > TCP Stream" per ricostruire la sessione.

## Legale
Cattura solo traffico che sei autorizzato a monitorare.
