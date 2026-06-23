# Sigma Detection Rules

[Sigma](https://github.com/SigmaHQ/sigma) is the universal open standard for SIEM detection rules.  
A single Sigma rule can be automatically converted to **Splunk SPL, Microsoft Sentinel KQL,  
Elasticsearch DSL, QRadar AQL, CrowdStrike NG-SIEM**, and 20+ other platforms.

## Rules in This Directory

| File | MITRE | Level | Description |
|---|---|---|---|
| `t1110-ssh-brute-force.yml` | T1110.001 | HIGH | SSH password guessing threshold |
| `t1046-network-scan.yml` | T1046 | MEDIUM | TCP SYN port scan detection |
| `t1190-web-exploit.yml` | T1190 + T1595.002 | HIGH | SQLi / XSS / scanner detection |
| `t1021-lateral-movement.yml` | T1021.004 + T1133 | MEDIUM | External SSH/RDP connection |

## Convert to Your SIEM

### Install pySigma

```bash
pip install pysigma pysigma-backend-elasticsearch pysigma-backend-splunk
```

### Convert to Elasticsearch (KQL)

```bash
sigma convert \
  -t elasticsearch \
  -p ecs_linux \
  rules/sigma/t1110-ssh-brute-force.yml
```

### Convert to Splunk SPL

```bash
sigma convert \
  -t splunk \
  rules/sigma/t1110-ssh-brute-force.yml
```

### Convert to Microsoft Sentinel (KQL)

```bash
sigma convert \
  -t microsoft365defender \
  rules/sigma/t1046-network-scan.yml
```

### Convert all rules at once

```bash
for rule in rules/sigma/*.yml; do
  echo "=== $rule ==="
  sigma convert -t elasticsearch -p ecs_linux "$rule"
done
```

## Rule Anatomy

```yaml
title:       Human-readable name
id:          UUID (unique, immutable)
status:      stable | test | experimental
description: Full description of what this detects and why
references:  External sources (MITRE, vendor docs)
author:      Rule author
date:        Creation date
tags:        MITRE ATT&CK mapping (attack.tXXXX.XXX)
logsource:   Where the logs come from (product, category, service)
detection:   The actual logic (selections + condition)
falsepositives: Known benign triggers
level:       informational | low | medium | high | critical
```

## Why Sigma Matters

- **Platform-agnostic**: write once, deploy anywhere
- **Versionable**: rules live in Git like code
- **Community**: [SigmaHQ/sigma-rules](https://github.com/SigmaHQ/sigma-rules) has 3000+ free rules
- **Standard**: used by Splunk, Microsoft, Elastic, IBM, and more
