# OSQuery - interroga l'endpoint come un database SQL
## Cos'e'
Espone il sistema (processi, utenti, connessioni, servizi) come tabelle SQL.
Fondamentale per detection ed endpoint visibility nei SOC.
## Uso base
```
osqueryi
osquery> SELECT name, path, pid FROM processes LIMIT 10;
osquery> SELECT * FROM listening_ports;
osquery> SELECT * FROM logged_in_users;
```
