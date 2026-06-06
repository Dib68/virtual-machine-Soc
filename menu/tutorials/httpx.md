# httpx - probe HTTP veloce
## Uso base
```
httpx -l domini.txt -title -status-code -tech-detect
echo target.com | httpx -silent
```
Identifica host web vivi, titoli, status code e tecnologie. Spesso usato
in pipeline con subfinder e nuclei.
