# Post-Incident Hardening Guide

> After the brute force attack in [`docs/WALKTHROUGH.md`](../WALKTHROUGH.md), the attacker gained root access.
> This guide covers the hardening steps to prevent recurrence.
>
> **Context**: This is Phase 4 (Eradication) of the NIST IR framework.
> Detection happened at T+9:10, containment at T+10:48.
> Hardening is applied during the recovery window.

---

## 1. SSH Hardening

The attack vector was SSH with password authentication enabled and a weak password (`toor`).

### 1.1 Disable root SSH login

```bash
# Edit /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config

# Verify
grep PermitRootLogin /etc/ssh/sshd_config
```

Expected output: `PermitRootLogin no`

### 1.2 Disable password authentication (keys only)

```bash
sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Add authorized key for legitimate access
mkdir -p /home/labuser/.ssh
echo "ssh-ed25519 AAAAC3Nza...your_public_key..." >> /home/labuser/.ssh/authorized_keys
chmod 700 /home/labuser/.ssh && chmod 600 /home/labuser/.ssh/authorized_keys
chown -R labuser:labuser /home/labuser/.ssh
```

### 1.3 Harden SSH configuration (full hardened sshd_config)

```bash
cat >> /etc/ssh/sshd_config << 'EOF'

# ── Security hardening (applied post-incident 2026-06-24) ──
Protocol 2
MaxAuthTries 3
MaxSessions 5
LoginGraceTime 30s
ClientAliveInterval 300
ClientAliveCountMax 2
AllowUsers labuser
DenyUsers root
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding no
PrintLastLog yes
Banner /etc/ssh/banner.txt
EOF
```

### 1.4 Create SSH warning banner

```bash
cat > /etc/ssh/banner.txt << 'EOF'
*******************************************************************
*  AUTHORIZED ACCESS ONLY — All connections are monitored and    *
*  logged. Unauthorized access attempts will be reported to      *
*  law enforcement.                                              *
*******************************************************************
EOF
```

### 1.5 Restart and verify

```bash
sshd -t && systemctl restart sshd

# Verify from a separate terminal (don't close current session!)
ssh -o PasswordAuthentication=no labuser@target -p 22
```

**Suricata detection impact**: After this change, SID 9000001 will still fire if someone sends SSH packets, but they will fail at protocol level before any authentication attempt.

---

## 2. Fail2Ban Configuration

Fail2ban automatically bans IPs after repeated failures.

### 2.1 Install and configure

```bash
apt-get install -y fail2ban

cat > /etc/fail2ban/jail.d/sshd-strict.conf << 'EOF'
[sshd]
enabled  = true
port     = ssh
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 3          # ban after 3 failures (down from default 5)
findtime = 600        # within 10 minutes
bantime  = 86400      # ban for 24 hours
action   = iptables-multiport[name=SSH, port=22, protocol=tcp]
EOF

systemctl enable fail2ban && systemctl restart fail2ban
```

### 2.2 Verify Fail2Ban is working

```bash
# Check banned IPs
fail2ban-client status sshd

# Check jails
fail2ban-client status

# Test: attempt 3 failed logins, then:
iptables -L -n | grep -i "fail2ban\|ban"
```

**Relationship with Suricata**: Fail2ban operates at the kernel (iptables) level — once an IP is banned, Suricata won't even see the packets. This means Suricata alerts will drop to zero for that IP (a sign containment worked).

---

## 3. Firewall Hardening (iptables)

### 3.1 Restrict SSH to management network only

```bash
# Only allow SSH from your management IP range
iptables -I INPUT -p tcp --dport 22 -s 192.168.1.0/24 -j ACCEPT
iptables -I INPUT -p tcp --dport 22 ! -s 192.168.1.0/24 -j DROP

# Save rules
iptables-save > /etc/iptables/rules.v4
```

### 3.2 Block the attacker's IP permanently

```bash
ATTACKER_IP="203.0.113.42"  # From the incident

iptables -I INPUT 1 -s "$ATTACKER_IP" -j DROP -m comment --comment "Blocked: brute force 2026-06-24"
iptables -I OUTPUT 1 -d "$ATTACKER_IP" -j DROP

iptables-save > /etc/iptables/rules.v4
```

### 3.3 Rate-limit new SSH connections

```bash
# Allow max 3 new SSH connections per minute per IP
iptables -I INPUT -p tcp --dport 22 -m state --state NEW \
  -m recent --set --name SSH_RATELIMIT

iptables -I INPUT -p tcp --dport 22 -m state --state NEW \
  -m recent --update --seconds 60 --hitcount 4 --name SSH_RATELIMIT \
  -j DROP
```

---

## 4. Credential Rotation

### 4.1 Change all passwords immediately

```bash
# Change all interactive user passwords
passwd root      # Use a strong random password (or disable: passwd -l root)
passwd labuser   # 20+ char random password

# Generate a strong password
openssl rand -base64 32
```

### 4.2 Check for unauthorized SSH keys

```bash
# Find all authorized_keys files on the system
find / -name "authorized_keys" -type f 2>/dev/null

# Check for recently modified auth files (within last hour)
find /home /root -name "authorized_keys" -newer /etc/passwd 2>/dev/null

# Remove all keys not explicitly authorized
for f in $(find / -name "authorized_keys" 2>/dev/null); do
  echo "=== $f ==="
  cat "$f"
done
```

### 4.3 Audit sudo access

```bash
# List all users with sudo privileges
getent group sudo
cat /etc/sudoers
find /etc/sudoers.d/ -type f -exec cat {} \;

# Remove unauthorized sudo entries
visudo  # Edit /etc/sudoers safely
```

---

## 5. Persistence Check

Attackers often leave backdoors. After gaining root, check for:

### 5.1 New crontabs

```bash
# Check all user crontabs
for user in $(cut -f1 -d: /etc/passwd); do
  echo "=== $user ==="; crontab -u "$user" -l 2>/dev/null || echo "(none)"
done

# Check system crontabs
ls -la /etc/cron*
find /etc/cron* -newer /etc/passwd -type f 2>/dev/null
```

### 5.2 New systemd services

```bash
# List recently created services
find /etc/systemd /usr/lib/systemd /home -name "*.service" -newer /etc/passwd 2>/dev/null

# Check for enabled but suspicious services
systemctl list-units --type=service --state=active | grep -v "^UNIT\|snapshot\|dbus\|ssh\|nginx\|network\|systemd-"
```

### 5.3 New users and SUID binaries

```bash
# Users created recently
awk -F: '{print $1, $3, $6}' /etc/passwd | sort -k2 -n | tail -10

# SUID binaries (these allow privilege escalation)
find / -perm -4000 -type f 2>/dev/null | grep -v '/bin/\|/usr/bin/\|/usr/sbin/'

# Unexpected binaries in /tmp, /dev, /var
find /tmp /dev /var -executable -type f 2>/dev/null
```

### 5.4 Network listeners

```bash
# New listening ports (compare to baseline)
ss -tlnp

# Compare with expected:
# Expected: 22 (SSH), 80/443 (nginx)
# Unexpected: anything else → investigate immediately
```

---

## 6. Auditd — Enhanced Logging

Enable `auditd` to log privileged operations that Filebeat/Suricata would miss:

```bash
apt-get install -y auditd

cat > /etc/audit/rules.d/99-soc-lab.rules << 'EOF'
# Log all authentication events
-w /var/log/auth.log -p rwa -k auth_log

# Log privilege escalation
-a always,exit -F arch=b64 -S execve -F euid=0 -k root_commands

# Log sudo usage
-w /etc/sudoers -p rwa -k sudoers
-w /etc/sudoers.d/ -p rwa -k sudoers

# Log SSH config changes
-w /etc/ssh/sshd_config -p rwa -k sshd_config

# Log crontab changes
-w /etc/cron.d/ -p rwa -k cron
-w /var/spool/cron/crontabs -p rwa -k cron

# Log new listeners
-a always,exit -F arch=b64 -S bind -k net_bind
EOF

augenrules --load
systemctl restart auditd
```

Auditd logs go to `/var/log/audit/audit.log` → add this path to Filebeat to ingest into the SIEM.

---

## 7. Post-Hardening Validation

Run these checks to verify the hardening is effective:

```bash
# 1. Try password auth (should fail)
ssh -o PasswordAuthentication=yes labuser@localhost -p 22
# Expected: "Permission denied (publickey)"

# 2. Try root login (should fail)
ssh root@localhost -p 22
# Expected: "Permission denied"

# 3. Verify iptables rules
iptables -L -n | grep "203.0.113.42"

# 4. Check fail2ban status
fail2ban-client status sshd

# 5. Verify no unexpected listeners
ss -tlnp | grep -v "22\|80\|443"

# 6. Suricata: run a simulated brute force, verify alert fires but connection is blocked
bash simulations/01-brute-force-ssh.sh localhost
# Expected: Suricata alert fires, connection refused after fail2ban kicks in
```

---

## 8. Suricata Rule Updates After Hardening

After hardening, update detection rules to reflect the new normal:

```suricata
# If you moved SSH to a non-standard port (e.g., 2222):
# Update the rule target port
alert tcp any any -> $HOME_NET 2222 (
  msg:"[MITRE T1110] SSH Brute Force Attempt";
  ...
  sid:9000001; rev:2;
)
```

Also add a rule to alert on SSH from any new source after the block:
```suricata
alert tcp !$HOME_NET any -> $HOME_NET 22 (
  msg:"[T1133] External SSH Connection Post-Hardening";
  flow:to_server,established;
  threshold: type limit, track by_src, count 1, seconds 3600;
  sid:9000080; rev:1;
)
```

---

## Summary Checklist

| # | Action | Command | Done? |
|---|---|---|---|
| 1 | Disable root SSH login | `sed -i 's/PermitRootLogin yes/PermitRootLogin no/'` | ☐ |
| 2 | Disable password auth | `sed -i 's/PasswordAuthentication yes/no/'` | ☐ |
| 3 | Install and configure fail2ban | `apt-get install fail2ban` | ☐ |
| 4 | Block attacker IP permanently | `iptables -I INPUT -s ATTACKER_IP -j DROP` | ☐ |
| 5 | Rotate all credentials | `passwd root && passwd labuser` | ☐ |
| 6 | Audit authorized_keys files | `find / -name "authorized_keys"` | ☐ |
| 7 | Check for persistence mechanisms | cron, systemd, SUID, listeners | ☐ |
| 8 | Enable auditd | `apt-get install auditd` | ☐ |
| 9 | Validate hardening | `ssh -o PasswordAuthentication=yes ...` | ☐ |
| 10 | Update Suricata rules | `make threat-intel && make validate` | ☐ |

---

*This guide follows NIST SP 800-61 Rev.2 — Computer Security Incident Handling Guide.*
*Cross-reference: [T1110 Playbook](../playbooks/T1110-SSH-BruteForce.md) · [WALKTHROUGH](../WALKTHROUGH.md)*
