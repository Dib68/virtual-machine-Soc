# Burp Suite - proxy per il web pentesting

## Cos'e'
Lo strumento di riferimento per testare applicazioni web: intercetta e
modifica le richieste HTTP tra browser e server.

## Avvio
```
burpsuite
```
1. Avvia Burp -> tab "Proxy" -> "Intercept is on".
2. Configura il browser per usare il proxy 127.0.0.1:8080
   (in Kali, Firefox ha gia' FoxyProxy/preset). Installa il certificato di Burp.
3. Naviga il sito: vedrai le richieste in Burp e potrai modificarle,
   inviarle al "Repeater" o all'"Intruder".

## Moduli chiave
- Proxy, Repeater, Intruder, Decoder, Comparer.
