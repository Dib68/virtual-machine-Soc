# Gobuster - brute force di directory e DNS

## Uso base
```
gobuster dir -u http://target -w /usr/share/wordlists/dirb/common.txt
gobuster dns -d dominio.com -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt
gobuster vhost -u http://target -w lista.txt
```
Scopre pagine, cartelle e sottodomini nascosti.
