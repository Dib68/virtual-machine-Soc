# Wapiti - scanner di vulnerabilita' web

## Uso base
```
wapiti -u http://target.local
wapiti -u http://target.local -m sql,xss,exec -f html -o report.html
```
Esegue audit "black box" cercando SQLi, XSS, inclusioni di file, ecc.
