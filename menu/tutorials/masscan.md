# Masscan - scanner ultra-veloce

## Cos'e'
Scanner di porte estremamente rapido, puo' scansionare grandi range di IP.

## Uso base
```
sudo masscan 192.168.1.0/24 -p80,443
sudo masscan 10.0.0.0/8 -p0-65535 --rate 1000 -oL out.txt
```
`--rate` controlla i pacchetti/sec (alza con cautela).

## Legale
Solo su reti autorizzate: rate alti possono saturare la rete.
