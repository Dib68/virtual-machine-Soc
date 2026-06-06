# Responder - avvelenamento LLMNR/NBT-NS/MDNS
## Cos'e'
Cattura hash di autenticazione Windows rispondendo a richieste di nome
broadcast. Tecnica classica nei pentest interni.
## Uso base
```
sudo responder -I eth0            # in ascolto sull'interfaccia
# gli hash NetNTLM catturati si crackano poi con hashcat/john
```
## Legale
Estremamente intrusivo: solo in laboratorio o reti autorizzate.
