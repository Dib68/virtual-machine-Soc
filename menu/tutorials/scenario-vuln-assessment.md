# Scenario guidato: vulnerability assessment di un'applicazione

Obiettivo: trovare vulnerabilita' note su un bersaglio locale.

## 0. Avvia il bersaglio
```
soclab targets up        # DVWA su http://localhost:8080
```

## 1. Scansione veloce con Nuclei
```
nuclei -u http://localhost:8080
nuclei -u http://localhost:8080 -t cves/
```

## 2. Scanner del web server
```
nikto -h http://localhost:8080
```

## 3. Scanner di vulnerabilita' completo (OpenVAS)
```
sudo gvm-setup        # solo la prima volta (lungo)
sudo gvm-start
```
Apri https://127.0.0.1:9392, crea un Target e un Task, leggi il report CVSS.

## 4. Genera il report
```
cyberreport pentest
```
