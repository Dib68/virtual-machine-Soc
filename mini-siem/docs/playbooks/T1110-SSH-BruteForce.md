# Incident Response Playbook — T1110.001: SSH Brute Force

| Field | Value |
|---|---|
| **MITRE Technique** | [T1110.001 — Password Guessing](https://attack.mitre.org/techniques/T1110/001/) |
| **Tactic** | TA0006 — Credential Access |
| **Severity** | HIGH / CRITICAL (if threshold exceeded) |
| **SLA Detection** | < 15 minutes |
| **SLA Containment** | < 30 minutes |
| **Author** | Damiano Di Biase |

---

## 1. Trigger Conditions

Alert fires when **one of the following** is true:

- Suricata SID 9000001: 5+ SSH connection attempts from same IP in 60 seconds
- Filebeat auth parser: 10+ `Failed password` entries from same IP in 5 minutes
- Elastic rule `t1110-brute-force.toml`: threshold of 5 failures by `source.ip`

---

## 2. Initial Triage (< 5 min)

```bash
# 1. Find the attacker IP in Kibana
# Security → Alerts → filter: rule.name: "*T1110*"

# 2. Check alert count and timeline
# Security → Timelines → New → filter by source.ip

# 3. Verify the attack is still ongoing
docker exec siem-suricata tail -20 /var/log/suricata/fast.log | grep "Brute Force"
```

**Questions to answer in triage:**

| Question | Where to check | Red flag |
|---|---|---|
| Is the source IP internal or external? | `source.geo.country_code` | Internal = possible compromised host |
| Did any login succeed? | auth.log `Accepted password` | Yes = immediate escalation |
| Is it a known Tor/VPN exit node? | AbuseIPDB enrichment | Yes = external attacker |
| What users were targeted? | auth log `auth.user` field | `root` + many users = automated tool |
| How many attempts total? | Alert count in Kibana | > 100 = credential stuffing tool |

---

## 3. Containment (< 30 min)

### 3a. Block the attacker IP

```bash
# Block immediately at network level
sudo iptables -I INPUT -s <ATTACKER_IP> -j DROP

# Make it persistent
sudo iptables-save > /etc/iptables/rules.v4

# Verify block is in place
sudo iptables -L INPUT -n | grep <ATTACKER_IP>
```

### 3b. Activate fail2ban

```bash
# Check if fail2ban is running
sudo systemctl status fail2ban

# Enable SSH jail if not active
sudo fail2ban-client set sshd banip <ATTACKER_IP>

# Verify ban
sudo fail2ban-client status sshd
```

### 3c. If internal IP is the source

```bash
# Isolate the compromised host from the network
# (lab: change VM network to host-only)

# Check what process is generating SSH connections
sudo ss -tnp | grep :22
sudo ps aux | grep ssh

# Look for scheduled tasks or cron jobs
sudo crontab -l
cat /etc/cron.*/*
```

---

## 4. Investigation

### 4a. Check if the attacker ever succeeded

```bash
# Search auth.log for successful logins from attacker IP
grep "Accepted" /var/log/auth.log | grep "<ATTACKER_IP>"

# Check Kibana: Security → Timelines
# Filter: source.ip: <ATTACKER_IP> AND event.outcome: success
```

### 4b. Pivot analysis — what else did this IP do?

```bash
# Query all indexes for the attacker IP
curl -s http://localhost:9200/siem-*/_search -H 'Content-Type: application/json' -d '{
  "query": {"term": {"source.ip": "<ATTACKER_IP>"}},
  "sort": [{"@timestamp": "asc"}],
  "size": 100
}' | python3 -m json.tool | grep -E "timestamp|signature|event_type"
```

Expected attack chain from this IP:
```
09:05 T1046 Port Scan      → discovered open SSH port
09:07 T1595.002 Nikto      → scanned for web vulns (same campaign)
09:09 T1110.001 Brute force → tried to brute SSH
09:14 ALERT fired
09:16 IP blocked
```

### 4c. Assess impact

- [ ] Were any files modified after the attack started? `find / -newer /tmp/attack-start -type f 2>/dev/null`
- [ ] Any new user accounts created? `grep "new user" /var/log/auth.log`
- [ ] Any scheduled tasks added? `crontab -l; ls /etc/cron.d/`
- [ ] Any outbound connections to unusual IPs? Check `siem-suricata-flow` index

---

## 5. Eradication

```bash
# Remove any SSH keys that may have been added
cat ~/.ssh/authorized_keys
# Remove unauthorized keys

# Reset passwords for targeted accounts
passwd root
passwd admin

# Audit all active sessions
who
w
last | head -20
```

---

## 6. Recovery

```bash
# If a host was compromised: rebuild from clean snapshot
# In Vagrant lab:
vagrant snapshot restore clean-baseline

# Re-enable services after containment
sudo systemctl start ssh

# Verify no backdoors remain
ss -tlnp | grep -v ":22\|:80\|:443"
find /tmp /var/tmp -perm /111 -type f 2>/dev/null
```

---

## 7. Post-Incident Actions

- [ ] Create TheHive case: `make create-case` (or manually via `http://localhost:9000`)
- [ ] Document MTTD and MTTR
- [ ] Add attacker IP to permanent blocklist
- [ ] Review Suricata threshold — reduce to 3 attempts?
- [ ] Enable `PasswordAuthentication no` in `/etc/ssh/sshd_config`
- [ ] Consider deploying SSH keys-only authentication
- [ ] Update AbuseIPDB with attacker IP report

---

## 8. Lessons Learned Template

```
Date: 
Incident ID: CASE-XXX
Analyst: 
MTTD: __ min
MTTR: __ min

Attack summary:
- Source IP: 
- Attack tool (inferred): Hydra / Medusa / Custom
- Attempts: 
- Successful logins: YES / NO

What worked:
- 

What to improve:
- 

Rule changes:
- 
```

---

## 9. References

- [MITRE T1110.001](https://attack.mitre.org/techniques/T1110/001/)
- [NIST IR Guide SP 800-61](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-61r2.pdf)
- [MITRE D3FEND: Network Traffic Filtering](https://d3fend.mitre.org/technique/d3f:NetworkTrafficFiltering/)
- [CIS Control 13 — Network Monitoring](https://www.cisecurity.org/controls/)
