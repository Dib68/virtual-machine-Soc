# Rule Tuning & False Positive Management

> **"Adding rules is easy. Tuning them is the real skill."**
>
> A detection rule that fires 500 times a day on legitimate traffic is worse than no rule —
> it trains analysts to ignore alerts (alert fatigue) and hides real incidents in the noise.

---

## The Cost of Untuned Rules

| Alert Fatigue Stage | Effect |
|---|---|
| 1. High FP rate | Analysts stop investigating every alert |
| 2. Normalization | "That rule always fires" becomes accepted |
| 3. Miss | A real incident fires the same rule — ignored |
| 4. Breach | Attacker operates undetected for weeks |

This is exactly what happened in the **2013 Target breach**: SIEM alerts fired, but analysts were overwhelmed with noise and missed the critical ones.

---

## Measuring False Positive Rate

Before tuning, establish a baseline:

```bash
# False positive rate for a specific rule (SID 9000010)
FP_RATE=$(make check | grep "9000010" | wc -l)
echo "SID 9000010 fired $FP_RATE times in the last hour"

# Elasticsearch: alert volume per rule (last 24h)
curl -s "http://localhost:9200/siem-suricata-*/_search" -H 'Content-Type: application/json' -d '{
  "size": 0,
  "query": {
    "bool": {
      "must": [
        {"term": {"suricata.event_type": "alert"}},
        {"range": {"@timestamp": {"gte": "now-24h"}}}
      ]
    }
  },
  "aggs": {
    "by_signature": {
      "terms": {"field": "suricata.alert.signature_id", "size": 20}
    }
  }
}' | python3 -m json.tool | grep -A2 "key"
```

**Target FP rate**: < 5% of alerts per rule per day should be false positives.

---

## Lab Rules — Known False Positive Sources

### SID 9000010 — Network Scan (T1046)
```
alert tcp any any -> $HOME_NET any (threshold: type both, track by_src, count 50, seconds 10)
```

**Problem**: Internal scanners, vulnerability management tools, and Docker health checks trigger this.

**Evidence of FP**:
```
# These IPs legitimately scan the network — NOT attackers:
172.20.0.1   (Docker gateway — health checks)
10.0.0.50    (Nessus/OpenVAS scanner — scheduled scan)
192.168.1.100 (Nagios monitoring — ICMP + TCP)
```

**Tuning options**:

Option A — Whitelist known scanner IPs in Suricata:
```suricata
# In suricata.yaml, add to vars:
vars:
  address-groups:
    SCANNERS: "[172.20.0.1, 10.0.0.50, 192.168.1.100]"

# In local.rules — add suppress:
suppress gen_id 1, sig_id 9000010, track by_src, ip $SCANNERS
```

Option B — Raise threshold (50 → 200 SYN in 10s):
```suricata
# Before (noisy):
threshold: type both, track by_src, count 50, seconds 10

# After (better signal):
threshold: type both, track by_src, count 200, seconds 10
```

Option C — Restrict to external sources only:
```suricata
# Before: any any -> $HOME_NET any
# After:  !$HOME_NET any -> $HOME_NET any
alert tcp !$HOME_NET any -> $HOME_NET any (...)
```

**Recommended**: Option C + Option A for internal scanner whitelist.

---

### SID 9000001 — SSH Brute Force (T1110)
```
threshold: type both, track by_src, count 5, seconds 60
```

**Problem**: Legitimate users who mistype their password trigger this in shared environments. Jump hosts with automated SSH connections can also trigger it.

**FP patterns to check in Kibana**:
```
# KQL query — find SID 9000001 alerts where login succeeded (possible FP chain)
suricata.alert.signature_id: 9000001 AND event.outcome: success
```

If you find cases where the brute force alert was followed by a successful login from the *same IP*, that's real. If the login never succeeded and the IP is internal, likely FP.

**Tuning**:
```suricata
# Raise threshold slightly for internal networks:
suppress gen_id 1, sig_id 9000001, track by_src, ip $HOME_NET

# Or add time-based suppression for maintenance windows:
# suppress gen_id 1, sig_id 9000001, track by_src, ip 10.0.0.20
```

---

### SID 9000060 — C2 Beacon Detection (T1071)
```
threshold: type both, track by_src, count 6, seconds 120
```

**Problem**: Health check endpoints, telemetry agents, and update checkers create regular small-packet HTTP traffic that looks like beaconing.

**FP checklist**:
- [ ] Is the destination IP a known CDN or cloud provider? (AWS, Azure, Cloudflare)
- [ ] Is the user-agent a known application (curl, python-requests)?
- [ ] Is the traffic to port 443 (not 80)? Encrypted beacons rarely show content-length

**Tuning — whitelist known legitimate destinations**:
```suricata
# Suppress alerts to known update servers
suppress gen_id 1, sig_id 9000060, track by_dst, ip [8.8.8.8, 1.1.1.1, 13.107.4.0/22]
```

---

## Suppression vs. Threshold Tuning

| Technique | Use Case | Risk |
|---|---|---|
| `suppress` by IP | Specific trusted source/dest | Attacker using whitelisted IP won't be detected |
| `suppress` by signature | Rule has no value in this environment | Entire technique class goes undetected |
| Raise `threshold` | FPs are real traffic at lower volume | Slow attacks below threshold evade detection |
| Time-window `suppress` | Maintenance windows | Must be removed after window |
| Rule `disabled` | Rule causes too much noise, no value | Complete blind spot |

**Never suppress**: any rule covering `event.category: authentication` + `event.outcome: success` — successful logins should always be investigated.

---

## Elastic Detection Rule Tuning (TOML)

For the detection rules in `rules/detection/`, tune via exceptions in Kibana's Security → Rules → Edit → Exceptions, or directly in the TOML:

```toml
# In t1110-brute-force.toml — add exceptions list
[[rule.exceptions_list]]
id = "endpoint-whitelist"
list_id = "endpoint-whitelist"
namespace_type = "single"
type = "detection"

# Or raise the threshold value field:
[rule.threshold]
field = ["source.ip"]
value = 10  # was 5 — raise if too many FPs
```

---

## Sigma Rule Tuning

Sigma rules use `filter` conditions to exclude known-good sources:

```yaml
# Current filter in t1110-ssh-brute-force.yml:
filter_local:
  src_ip|cidr:
    - '127.0.0.0/8'
    - '10.0.0.0/8'
    - '172.16.0.0/12'
    - '192.168.0.0/16'

# Extended filter — add jump hosts:
filter_jump_hosts:
  src_ip:
    - '10.0.1.50'   # bastion host
    - '10.0.1.51'   # ansible controller

condition: selection and not (filter_local or filter_jump_hosts)
```

---

## Tuning Workflow (Weekly)

```
1. MEASURE   → Kibana: identify top 5 highest-volume rules (last 7 days)
2. SAMPLE    → Pick 20 random alerts from each noisy rule
3. CLASSIFY  → True Positive / False Positive / Unknown
4. ROOT CAUSE → Why are FPs happening? (traffic pattern, threshold, scope)
5. TUNE      → Apply smallest possible change (suppress > threshold > disable)
6. VALIDATE  → Run 48h soak, re-measure FP rate
7. DOCUMENT  → Add note to this file with SID, change, reason, date
```

---

## Tuning Log

| Date | SID | Change | Reason | FP Rate Before | FP Rate After |
|---|---|---|---|---|---|
| *Template* | 9000010 | Added `!$HOME_NET` scope | Docker health checks | 40/day | 3/day |
| *Template* | 9000001 | Raised threshold 5→8 | Password managers | 12/day | 1/day |

> Add your own tuning changes here to maintain an audit trail.

---

## References

- [SANS: Alert Triage and False Positive Reduction](https://www.sans.org/white-papers/)
- [Elastic: Create Detection Rule Exceptions](https://www.elastic.co/guide/en/security/current/detections-ui-exceptions.html)
- [Suricata: Rule Management](https://docs.suricata.io/en/latest/rule-management/)
- [Sigma: Filter Conditions](https://github.com/SigmaHQ/sigma-specification)
