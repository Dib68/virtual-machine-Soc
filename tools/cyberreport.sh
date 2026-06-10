#!/usr/bin/env bash
# cyberreport - crea un template di report (pentest o incident response)
set -uo pipefail
DIR="$HOME/reports"; mkdir -p "$DIR"
TYPE="${1:-pentest}"; DATE=$(date +%Y-%m-%d)
FILE="$DIR/report-$TYPE-$DATE.md"
case "$TYPE" in
  pentest)
cat > "$FILE" <<EOF
# Report di Penetration Test
- Data: $DATE
- Cliente/Sistema:
- Tester:
- Ambito (scope):
- Autorizzazione (rif.):

## Sommario esecutivo
(riassunto non tecnico dei risultati e del rischio complessivo)

## Metodologia
(es. OWASP, PTES, MITRE ATT&CK)

## Risultati
### [CRITICO] Titolo vulnerabilita'
- Descrizione:
- Impatto:
- Evidenze (screenshot/comandi):
- CVSS:
- Remediation:

### [ALTO] ...
### [MEDIO] ...
### [BASSO] ...

## Conclusioni e raccomandazioni
EOF
  ;;
  ir|incident)
cat > "$FILE" <<EOF
# Report di Incident Response
- Data: $DATE
- Analista:
- Sistema/i coinvolti:

## Timeline dell'incidente
| Orario | Evento | Fonte |
|---|---|---|

## Indicatori di compromissione (IOC)
- IP:
- Domini:
- Hash:

## Tecniche MITRE ATT&CK osservate
- Txxxx -

## Azioni di contenimento ed eradicazione
## Lezioni apprese
EOF
  ;;
  web)
cat > "$FILE" <<EOF
# Report di Web Application Assessment
- Data: $DATE
- Applicazione/URL:
- Tester:
- Ambito (scope) e autorizzazione:

## Sommario esecutivo
(rischio complessivo in linguaggio non tecnico)

## Copertura OWASP Top 10
| Categoria | Esito | Note |
|---|---|---|
| A01 Broken Access Control | | |
| A02 Cryptographic Failures | | |
| A03 Injection | | |
| A04 Insecure Design | | |
| A05 Security Misconfiguration | | |
| A06 Vulnerable Components | | |
| A07 Auth Failures | | |
| A08 Integrity Failures | | |
| A09 Logging/Monitoring | | |
| A10 SSRF | | |

## Risultati dettagliati
### [CRITICO] Titolo
- Endpoint/Parametro:
- Descrizione e impatto:
- Evidenze (richiesta/risposta, payload):
- CVSS:
- Remediation:

## Conclusioni e raccomandazioni
EOF
  ;;
  *) echo "uso: cyberreport [pentest|ir|web]"; exit 1 ;;
esac
echo "Report creato: $FILE"
