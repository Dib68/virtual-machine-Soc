# OpenVAS / Greenbone (GVM) - Vulnerability Scanner

## Cos'e'
Scanner di vulnerabilita' completo, alternativa open source a Nessus.
Molto richiesto per ruoli di Vulnerability Assessment.

## Avvio (prima volta)
```
sudo gvm-setup        # configurazione iniziale (lunga, una sola volta)
sudo gvm-check-setup  # verifica
sudo gvm-start        # avvia i servizi
```
Poi apri il browser su https://127.0.0.1:9392 (utente creato da gvm-setup).

## Uso
Crea un "Target" (IP/host) e un "Task" di scansione, poi consulta il report
con le vulnerabilita' classificate per gravita' (CVSS).
