# Hashcat - cracking ad alte prestazioni

## Uso base
```
hashcat -m 0 -a 0 hash.txt rockyou.txt     # MD5 con wordlist
hashcat -m 1000 -a 0 ntlm.txt rockyou.txt  # NTLM
hashcat -m 0 -a 3 hash.txt ?d?d?d?d        # brute force 4 cifre
```
`-m` = tipo di hash, `-a` = modalita' attacco. `hashcat --help` per la lista.

## Legale
Solo su hash autorizzati.
