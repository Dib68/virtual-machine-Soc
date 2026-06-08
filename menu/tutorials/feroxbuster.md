# Feroxbuster - content discovery ricorsivo
## Uso base
```
feroxbuster -u http://target -w /usr/share/seclists/Discovery/Web-Content/common.txt
feroxbuster -u http://target -x php,txt,html -d 2
```
Veloce e ricorsivo, alternativa moderna a gobuster/dirb.
