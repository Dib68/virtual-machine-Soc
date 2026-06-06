# Aircrack-ng - sicurezza Wi-Fi

## Flusso tipico (richiede scheda Wi-Fi in monitor mode)
```
sudo airmon-ng start wlan0
sudo airodump-ng wlan0mon                  # elenca le reti
sudo airodump-ng -c 6 --bssid AA:BB:CC:DD:EE:FF -w cap wlan0mon
sudo aireplay-ng --deauth 5 -a AA:BB:CC:DD:EE:FF wlan0mon  # cattura handshake
aircrack-ng -w rockyou.txt cap-01.cap      # crack WPA/WPA2
```
Nota: in VirtualBox serve un adattatore Wi-Fi USB con supporto monitor mode.

## Legale
Solo sulla TUA rete Wi-Fi.
