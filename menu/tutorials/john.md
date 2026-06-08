# John the Ripper - cracking di password

## Uso base
```
john --wordlist=/usr/share/wordlists/rockyou.txt hash.txt
john --show hash.txt                       # mostra le password trovate
unshadow /etc/passwd /etc/shadow > hashes  # prepara hash Linux
```
Supporta moltissimi formati di hash (rileva da solo o con `--format=`).

## Legale
Solo su hash di tua proprieta'/autorizzati.
