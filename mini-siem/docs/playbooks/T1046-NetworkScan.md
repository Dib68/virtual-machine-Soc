# Incident Response Playbook — T1046: Network Service Scanning

| Field | Value |
|---|---|
| **MITRE Technique** | [T1046 — Network Service Scanning](https://attack.mitre.org/techniques/T1046/) |
| **Tactic** | TA0007 — Discovery |
| **Severity** | MEDIUM (external) / HIGH (internal) |
| **SLA Detection** | < 10 minutes |
| **SLA Containment** | < 60 minutes |

---

## 1. Trigger Conditions

- Suricata SID 9000010: 50+ SYN packets to different ports in 10 seconds
- Suricata SID 9000011: Nmap SYN scan signature (window:1024, 30+ SYN in 5s)
- Elastic rule `t1046-network-scan.toml`

---

## 2. Triage

**Is this expected or unexpected?**

| Scenario | Action |
|---|---|
| External IP, no prior activity | Monitor — may be initial recon before attack |
| External IP + prior T1110 alert from same IP | ESCALATE — coordinated attack |
| Internal IP (pentest scheduled) | Verify with change management, close alert |
| Internal IP (no change ticket) | Treat as compromised host — investigate |

**Key fields to check in Kibana:**

```
suricata.alert.signature     → rule that fired
source.ip                    → scanner
destination.ip               → targets
source.geo.country_code      → external origin?
@timestamp                   → duration of scan
```

---

## 3. Containment

```bash
# Block scanning IP at firewall level
sudo iptables -I INPUT -s <SCANNER_IP> -j DROP

# If internal: investigate the scanning process
sudo ss -tnp | grep ESTABLISHED
sudo netstat -an | grep SYN_SENT | awk '{print $5}' | cut -d: -f1 | sort -u

# Check what's generating the scan
sudo lsof -i -P | grep nmap
sudo ps aux | grep -E "nmap|masscan|zmap"
```

---

## 4. Investigation

```bash
# What ports were targeted?
curl -s http://localhost:9200/siem-suricata-*/_search \
  -H 'Content-Type: application/json' -d '{
  "query": {"bool": {"must": [
    {"term": {"source.ip": "<SCANNER_IP>"}},
    {"term": {"suricata.event_type": "alert"}}
  ]}},
  "aggs": {"ports": {"terms": {"field": "suricata.dest_port", "size": 20}}}
}' | python3 -c "
import json,sys
for b in json.load(sys.stdin)['aggregations']['ports']['buckets']:
    print(f'  port {b[\"key\"]:>5}  →  {b[\"doc_count\"]} packets')
"

# Check if scan was followed by exploitation attempts
grep "<SCANNER_IP>" /var/log/suricata/fast.log | grep -v "Port Scan"
```

---

## 5. Common Port Interpretation

| Port(s) Found | Likely Goal |
|---|---|
| 22 | SSH brute force planned |
| 80, 443, 8080 | Web app attack planned |
| 3389 | RDP attack planned (T1133) |
| 445 | SMB exploit (EternalBlue etc.) |
| 1433, 3306, 5432 | Database attack |
| All ports (1-65535) | Full reconnaissance sweep |

---

## References

- [MITRE T1046](https://attack.mitre.org/techniques/T1046/)
- [MITRE D3FEND: Network Traffic Filtering](https://d3fend.mitre.org/technique/d3f:NetworkTrafficFiltering/)
