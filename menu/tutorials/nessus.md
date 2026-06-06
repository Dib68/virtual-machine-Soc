# Nessus - vulnerability scanner commerciale
## Cos'e'
Tra gli scanner di vulnerabilita' piu' citati negli annunci (versione
Essentials gratuita fino a 16 IP).
## Installazione (manuale, richiede registrazione)
1. Scarica il .deb da https://www.tenable.com/downloads/nessus
2. `sudo dpkg -i Nessus-*.deb && sudo systemctl start nessusd`
3. Apri https://localhost:8834 e completa la configurazione.
## Alternativa gia' presente in VM
OpenVAS/Greenbone (vedi tutorial 'openvas') copre lo stesso ruolo, gratis.
