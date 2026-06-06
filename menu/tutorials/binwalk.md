# Binwalk - analisi di firmware e file binari

## Uso base
```
binwalk firmware.bin              # mostra i contenuti riconosciuti
binwalk -e firmware.bin           # estrae i file incorporati
binwalk -Me firmware.bin          # estrazione ricorsiva
```
Utile in IoT/forensics per scomporre immagini di firmware.
