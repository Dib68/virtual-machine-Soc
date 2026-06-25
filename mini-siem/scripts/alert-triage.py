#!/usr/bin/env python3
"""
Alert Triage — Mini-SIEM Lab
Queries Elasticsearch for recent alerts, correlates by source IP,
calculates priority scores, and recommends actions.

Usage:
    python3 scripts/alert-triage.py
    python3 scripts/alert-triage.py --hours 48 --min-severity HIGH
    python3 scripts/alert-triage.py --json --save triage-report.json

Priority model:
    score = severity_score + volume_score + correlation_bonus + threat_intel_score
    CRITICAL ≥ 80 | HIGH ≥ 60 | MEDIUM ≥ 40 | LOW < 40
"""

import argparse
import json
import os
import sys
from collections import defaultdict
from datetime import datetime, timezone

import requests

try:
    from rich.console import Console
    from rich.table import Table
    from rich import box
    RICH = True
except ImportError:
    RICH = False


ES_URL = os.getenv("ES_URL", "http://localhost:9200")
ABUSEIPDB_KEY = os.getenv("ABUSEIPDB_API_KEY", "")


def parse_args():
    p = argparse.ArgumentParser(description="Alert triage and prioritization")
    p.add_argument("--hours", type=int, default=24, help="Look back N hours (default: 24)")
    p.add_argument("--min-severity", choices=["LOW", "MEDIUM", "HIGH", "CRITICAL"],
                   default="LOW", help="Minimum severity to display")
    p.add_argument("--json", action="store_true", dest="json_output", help="Output as JSON")
    p.add_argument("--save", metavar="FILE", help="Save JSON report to file")
    p.add_argument("--no-enrich", action="store_true", help="Skip ip-api.com enrichment")
    p.add_argument("--top", type=int, default=20, help="Show top N IPs (default: 20)")
    return p.parse_args()


def es_query(index, body):
    try:
        r = requests.post(
            f"{ES_URL}/{index}/_search",
            json=body,
            timeout=15,
            headers={"Content-Type": "application/json"},
        )
        r.raise_for_status()
        return r.json()
    except requests.exceptions.ConnectionError:
        print(f"ERROR: Cannot reach Elasticsearch at {ES_URL}", file=sys.stderr)
        print("       Run: make up", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: ES query failed: {e}", file=sys.stderr)
        return {}


def fetch_alerts(hours):
    """Return all alerts in the last N hours grouped by source IP."""
    body = {
        "size": 1000,
        "_source": [
            "source.ip", "suricata.alert.signature", "suricata.alert.signature_id",
            "suricata.alert.severity", "mitre.technique", "mitre.tactic",
            "rule.name", "rule.id", "alert.severity_label",
            "destination.ip", "destination.port", "@timestamp",
        ],
        "query": {
            "bool": {
                "must": [
                    {"term": {"suricata.event_type": "alert"}},
                    {"range": {"@timestamp": {"gte": f"now-{hours}h"}}},
                ],
                "must_not": [
                    {"terms": {"source.ip": ["127.0.0.1", "::1"]}},
                ],
            }
        },
        "sort": [{"@timestamp": {"order": "desc"}}],
    }
    result = es_query("siem-suricata-*", body)
    hits = result.get("hits", {}).get("hits", [])
    grouped = defaultdict(list)
    for h in hits:
        src = h["_source"].get("source.ip") or h["_source"].get("suricata.src_ip", "unknown")
        grouped[src].append(h["_source"])
    return grouped


def fetch_ssh_failures(hours):
    """Return SSH failed auth counts per source IP."""
    body = {
        "size": 0,
        "query": {
            "bool": {
                "must": [
                    {"term": {"event.outcome": "failure"}},
                    {"range": {"@timestamp": {"gte": f"now-{hours}h"}}},
                ]
            }
        },
        "aggs": {
            "by_ip": {"terms": {"field": "source.ip", "size": 100}}
        },
    }
    result = es_query("siem-auth-*", body)
    buckets = result.get("aggregations", {}).get("by_ip", {}).get("buckets", [])
    return {b["key"]: b["doc_count"] for b in buckets}


def geo_enrich(ip):
    """Lightweight GeoIP/ASN lookup via ip-api.com (no key needed)."""
    try:
        r = requests.get(
            f"http://ip-api.com/json/{ip}",
            params={"fields": "status,country,countryCode,city,isp,org,as,proxy,hosting"},
            timeout=5,
        )
        data = r.json()
        if data.get("status") == "success":
            flags = []
            if data.get("proxy"):
                flags.append("VPN/Proxy")
            if data.get("hosting"):
                flags.append("Hosting/VPS")
            return {
                "country": data.get("country", "?"),
                "country_code": data.get("countryCode", "?"),
                "city": data.get("city", "?"),
                "isp": data.get("isp", "?"),
                "asn": data.get("as", "?"),
                "flags": flags,
            }
    except Exception:
        pass
    return {}


def abuseipdb_check(ip):
    """Check AbuseIPDB confidence score (requires API key)."""
    if not ABUSEIPDB_KEY:
        return None
    try:
        r = requests.get(
            "https://api.abuseipdb.com/api/v2/check",
            headers={"Key": ABUSEIPDB_KEY, "Accept": "application/json"},
            params={"ipAddress": ip, "maxAgeInDays": 30},
            timeout=8,
        )
        data = r.json().get("data", {})
        return {
            "confidence": data.get("abuseConfidenceScore", 0),
            "total_reports": data.get("totalReports", 0),
            "isp": data.get("isp", "?"),
            "is_tor": data.get("isTor", False),
        }
    except Exception:
        return None


def calculate_priority(alerts, ssh_fails=0, abuseipdb_score=0):
    """
    Priority score (0–100):
      severity_score   = weighted avg Suricata severity (inverted: 1=critical → high score)
      volume_score     = capped contribution from alert count + SSH fails
      correlation      = bonus for multi-technique / multi-tactic correlation
      threat_intel     = AbuseIPDB confidence (if key provided)
    """
    if not alerts:
        return 0, "LOW"

    # Suricata severity: 1=critical(worst) → 4=low(best), invert for scoring
    severity_map = {1: 40, 2: 30, 3: 15, 4: 5}
    sev_scores = [severity_map.get(a.get("suricata.alert.severity", 4), 5) for a in alerts]
    severity_score = max(sev_scores)

    # Volume
    total_events = len(alerts) + ssh_fails
    volume_score = min(total_events * 1.5, 20)

    # Multi-technique correlation (same IP, different attack vectors = campaign)
    techniques = set(
        a.get("mitre.technique") or a.get("rule.name", "") for a in alerts
    )
    techniques.discard("")
    if len(techniques) >= 3:
        correlation = 25
    elif len(techniques) == 2:
        correlation = 15
    else:
        correlation = 0

    # Threat intel
    ti_score = min(abuseipdb_score * 0.2, 20)

    total = severity_score + volume_score + correlation + ti_score

    if total >= 80:
        return total, "CRITICAL"
    if total >= 60:
        return total, "HIGH"
    if total >= 40:
        return total, "MEDIUM"
    return total, "LOW"


def recommend_action(priority, geo, abuseipdb):
    """Suggest analyst action based on priority and enrichment."""
    confidence = (abuseipdb or {}).get("confidence", 0)
    is_tor = (abuseipdb or {}).get("is_tor", False)
    flags = (geo or {}).get("flags", [])

    if priority == "CRITICAL" or confidence > 80 or is_tor:
        return "BLOCK + ESCALATE"
    if priority == "HIGH" or confidence > 40 or "VPN/Proxy" in flags:
        return "INVESTIGATE"
    if priority == "MEDIUM":
        return "MONITOR"
    return "REVIEW (possible FP)"


def triage(args):
    now_str = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    alerts_by_ip = fetch_alerts(args.hours)
    ssh_fails_by_ip = fetch_ssh_failures(args.hours)

    all_ips = set(alerts_by_ip.keys()) | set(ssh_fails_by_ip.keys())
    if not all_ips:
        print(f"No alerts in the last {args.hours}h. Run: make attack-all")
        return []

    min_sev_rank = {"LOW": 0, "MEDIUM": 1, "HIGH": 2, "CRITICAL": 3}
    results = []

    for ip in all_ips:
        if ip == "unknown":
            continue
        ip_alerts = alerts_by_ip.get(ip, [])
        ssh_count = ssh_fails_by_ip.get(ip, 0)

        geo = {} if args.no_enrich else geo_enrich(ip)
        abuseipdb = abuseipdb_check(ip)
        abuseipdb_score = (abuseipdb or {}).get("confidence", 0)

        score, priority = calculate_priority(ip_alerts, ssh_count, abuseipdb_score)
        action = recommend_action(priority, geo, abuseipdb)

        techniques = list({
            a.get("mitre.technique") or a.get("rule.name", "")
            for a in ip_alerts
            if a.get("mitre.technique") or a.get("rule.name")
        })

        entry = {
            "ip": ip,
            "priority": priority,
            "score": round(score, 1),
            "alert_count": len(ip_alerts),
            "ssh_failures": ssh_count,
            "techniques": techniques[:4],
            "action": action,
            "geo": geo,
            "abuseipdb": abuseipdb,
            "latest_alert": ip_alerts[0].get("@timestamp", "") if ip_alerts else "",
            "rule_names": list({
                a.get("rule.name") or a.get("suricata.alert.signature", "")
                for a in ip_alerts
            })[:3],
        }
        results.append(entry)

    results.sort(key=lambda x: x["score"], reverse=True)
    results = [r for r in results
               if min_sev_rank.get(r["priority"], 0)
               >= min_sev_rank.get(args.min_severity, 0)]
    results = results[: args.top]

    if args.save:
        report = {"generated_at": now_str, "hours": args.hours, "entries": results}
        with open(args.save, "w") as f:
            json.dump(report, f, indent=2)
        print(f"Report saved: {args.save}")

    return results


def print_table(results, hours):
    if not results:
        print("No results above the selected severity threshold.")
        return

    PRIORITY_COLOR = {
        "CRITICAL": "\033[1;31m",
        "HIGH":     "\033[0;31m",
        "MEDIUM":   "\033[1;33m",
        "LOW":      "\033[0;32m",
    }
    NC = "\033[0m"
    BOLD = "\033[1m"

    print(f"\n{BOLD}Mini-SIEM Alert Triage — last {hours}h  ({len(results)} IPs){NC}\n")

    header = f"{'PRIORITY':<10} {'SCORE':>5}  {'IP':<16} {'ALERTS':>6} {'SSH':>4}  {'COUNTRY':<12} {'TECHNIQUES':<35} {'ACTION'}"
    print(f"{BOLD}{header}{NC}")
    print("─" * len(header))

    for r in results:
        color = PRIORITY_COLOR.get(r["priority"], "")
        country = r.get("geo", {}).get("country_code", "??")
        techniques = ", ".join(r["techniques"][:2]) or "—"
        if len(r["techniques"]) > 2:
            techniques += f" +{len(r['techniques']) - 2}"
        print(
            f"{color}{r['priority']:<10}{NC} "
            f"{r['score']:>5.0f}  "
            f"{r['ip']:<16} "
            f"{r['alert_count']:>6} "
            f"{r['ssh_failures']:>4}  "
            f"{country:<12} "
            f"{techniques:<35} "
            f"{r['action']}"
        )

    print()

    # Detail block for CRITICAL/HIGH
    critical = [r for r in results if r["priority"] in ("CRITICAL", "HIGH")]
    if critical:
        print(f"{BOLD}── Priority Investigation Queue ──────────────────────{NC}")
        for r in critical[:5]:
            color = PRIORITY_COLOR.get(r["priority"], "")
            geo = r.get("geo", {})
            abuse = r.get("abuseipdb") or {}
            print(f"\n  {color}[{r['priority']}]{NC} {r['ip']}")
            if geo:
                print(f"    Location : {geo.get('city','?')}, {geo.get('country','?')}")
                print(f"    ISP      : {geo.get('isp','?')}")
                print(f"    ASN      : {geo.get('asn','?')}")
                if geo.get("flags"):
                    print(f"    Flags    : {', '.join(geo['flags'])}")
            if abuse:
                print(f"    AbuseIPDB: confidence {abuse.get('confidence',0)}% — {abuse.get('total_reports',0)} reports")
                if abuse.get("is_tor"):
                    print(f"    ⚠ Tor exit node")
            if r["rule_names"]:
                print(f"    Rules    : {'; '.join(r['rule_names'])}")
            print(f"    Action   : {r['action']}")

    print()
    print(f"  ES index: siem-suricata-*  |  Kibana: http://localhost:5601")
    print()


def main():
    args = parse_args()

    results = triage(args)

    if args.json_output:
        print(json.dumps(results, indent=2))
    else:
        print_table(results, args.hours)


if __name__ == "__main__":
    main()
