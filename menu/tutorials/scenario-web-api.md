# Scenario guidato: test di sicurezza di una API REST

Obiettivo: valutare la sicurezza di una API REST su un bersaglio AUTORIZZATO
(es. lo stack bersagli del SOC Lab: `soclab targets up`).

## 1. Scoperta degli endpoint
```
ffuf -u https://api.esempio.local/FUZZ -w /usr/share/wordlists/dirb/common.txt
# oppure
gobuster dir -u https://api.esempio.local -w /usr/share/wordlists/dirb/common.txt
```

## 2. Analisi del traffico con un proxy
- Avvia Burp Suite o OWASP ZAP e imposta il proxy del client/app.
- Cattura le richieste reali per capire parametri, header e token.

## 3. Autenticazione e autorizzazione
- Prova accessi senza token o con token di un altro utente (IDOR/BOLA).
```
curl -i https://api.esempio.local/v1/users/1
curl -i -H "Authorization: Bearer <token_altro_utente>" https://api.esempio.local/v1/users/2
```

## 4. Scansione automatica
```
nuclei -u https://api.esempio.local -tags api,exposure
wapiti -u https://api.esempio.local
```

## 5. Injection sui parametri
```
sqlmap -u "https://api.esempio.local/v1/search?q=test" --batch --level 2
```

## 6. Checklist OWASP API Top 10
- BOLA (autorizzazione a livello di oggetto), autenticazione debole,
  esposizione eccessiva dei dati, rate limiting assente, misconfigurazioni.

## Note
- Opera solo su API tue o esplicitamente autorizzate.
- Genera il report con `cyberreport web`.
