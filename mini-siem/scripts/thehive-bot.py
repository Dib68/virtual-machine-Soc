#!/usr/bin/env python3
"""
Mini-SIEM → TheHive Integration Bot
────────────────────────────────────
Queries Elasticsearch for new high-severity alerts and automatically creates
structured incident cases in TheHive with MITRE ATT&CK tagging, observables,
and analyst assignment.

Usage:
    python3 scripts/thehive-bot.py [--dry-run] [--since 1h] [--min-severity high]

Requirements:
    pip install requests python-dateutil

TheHive: http://localhost:9000  (from docker-compose soclab thehive)
Elastic:  http://localhost:9200
"""

import argparse
import json
import sys
import time
from datetime import datetime, timezone
from typing import Optional

import requests
from requests.exceptions import ConnectionError, Timeout

# ── Configuration ──────────────────────────────────────────────────────
ES_URL        = "http://localhost:9200"
THEHIVE_URL   = "http://localhost:9000"
THEHIVE_KEY   = "thehive-api-key"          # Set in TheHive → Settings → API Keys
ES_INDEX      = "siem-suricata-*,siem-auth-*"
DEFAULT_SINCE = "1h"

SEVERITY_MAP = {
    "low":      1,
    "medium":   2,
    "high":     3,
    "critical": 4,
}

MITRE_TAGS = {
    "T1110": ["attack.credential_access", "attack.t1110", "brute_force"],
    "T1046": ["attack.discovery", "attack.t1046", "port_scan"],
    "T1190": ["attack.initial_access", "attack.t1190", "web_exploit"],
    "T1021": ["attack.lateral_movement", "attack.t1021", "remote_services"],
    "T1595": ["attack.reconnaissance", "attack.t1595", "active_scanning"],
    "T1071": ["attack.command_and_control", "attack.t1071", "c2_beacon"],
    "T1048": ["attack.exfiltration", "attack.t1048", "dns_tunnel"],
    "T1133": ["attack.persistence", "attack.t1133", "external_remote"],
}


# ── Elasticsearch helpers ───────────────────────────────────────────────

def fetch_alerts(since: str, min_severity: str) -> list[dict]:
    """Query ES for Suricata alerts above the minimum severity."""
    severity_threshold = {
        "low": 4, "medium": 3, "high": 2, "critical": 1
    }.get(min_severity.lower(), 2)

    query = {
        "size": 50,
        "sort": [{"@timestamp": "desc"}],
        "query": {
            "bool": {
                "must": [
                    {"term": {"suricata.event_type": "alert"}},
                    {"range": {"@timestamp": {"gte": f"now-{since}"}}},
                    {"range": {"suricata.alert.severity": {"lte": severity_threshold}}},
                ],
                "must_not": [
                    {"terms": {"source.ip": ["127.0.0.1", "::1"]}}
                ]
            }
        },
        "_source": [
            "@timestamp", "source.ip", "destination.ip", "destination.port",
            "suricata.alert.signature", "suricata.alert.severity",
            "suricata.alert.sid", "mitre.tactic", "mitre.technique",
            "alert.severity_label", "source.geo.country_code",
        ]
    }

    try:
        r = requests.post(
            f"{ES_URL}/{ES_INDEX}/_search",
            json=query,
            headers={"Content-Type": "application/json"},
            timeout=10,
        )
        r.raise_for_status()
        hits = r.json().get("hits", {}).get("hits", [])
        return [h["_source"] for h in hits]
    except ConnectionError:
        print(f"[ERROR] Cannot connect to Elasticsearch at {ES_URL}")
        print("        Run 'make up' to start the lab stack.")
        sys.exit(1)
    except Exception as e:
        print(f"[ERROR] ES query failed: {e}")
        return []


def group_by_campaign(alerts: list[dict]) -> dict[str, list[dict]]:
    """Group alerts by source IP (each IP = one case)."""
    groups: dict[str, list[dict]] = {}
    for alert in alerts:
        ip = alert.get("source.ip", "unknown")
        groups.setdefault(ip, []).append(alert)
    return groups


# ── TheHive helpers ────────────────────────────────────────────────────

def thehive_headers() -> dict:
    return {
        "Authorization": f"Bearer {THEHIVE_KEY}",
        "Content-Type": "application/json",
    }


def case_exists(source_ip: str) -> Optional[str]:
    """Return case ID if an open case for this IP already exists."""
    try:
        r = requests.post(
            f"{THEHIVE_URL}/api/v1/case/_search",
            headers=thehive_headers(),
            json={
                "query": [
                    {"_name": "filter", "_field": "status", "_value": "Open"},
                    {"_name": "filter", "_field": "title", "_like": f"%{source_ip}%"},
                ]
            },
            timeout=5,
        )
        cases = r.json()
        if isinstance(cases, list) and cases:
            return cases[0].get("_id")
    except Exception:
        pass
    return None


def build_case_payload(source_ip: str, alerts: list[dict]) -> dict:
    """Build the TheHive v5 case creation payload."""
    signatures = list({a.get("suricata.alert.signature", "") for a in alerts})
    techniques = list({a.get("mitre.technique", "") for a in alerts if a.get("mitre.technique")})
    tactic = next((a.get("mitre.tactic", "") for a in alerts if a.get("mitre.tactic")), "")
    severity_label = alerts[0].get("alert.severity_label", "MEDIUM")
    country = alerts[0].get("source.geo.country_code", "??")

    severity = SEVERITY_MAP.get(severity_label.lower(), 2)

    # Build MITRE tags
    tags = ["mini-siem-lab", "automated", f"country:{country}"]
    for tech in techniques:
        tech_id = tech.split(" ")[0].replace("T", "")
        tech_key = f"T{tech_id}"
        tags.extend(MITRE_TAGS.get(tech_key, [f"mitre.{tech_key.lower()}"]))
    tags = list(set(tags))

    # Build description with full alert list
    alert_lines = "\n".join(
        f"- `{a.get('@timestamp', '?')}` — {a.get('suricata.alert.signature', '?')}"
        for a in sorted(alerts, key=lambda x: x.get("@timestamp", ""))[:20]
    )

    description = f"""## Automated Case — Mini-SIEM Lab

**Source IP:** `{source_ip}` ({country})
**Total alerts:** {len(alerts)}
**Tactic:** {tactic}
**Techniques:** {', '.join(techniques)}

### Alert Timeline
{alert_lines}

### Signatures Triggered
{chr(10).join(f'- {s}' for s in signatures)}

---
*Created automatically by thehive-bot.py*
*Source: Elasticsearch index `siem-suricata-*`*
"""

    return {
        "title": f"[{severity_label}] {source_ip} — {len(alerts)} alerts · {tactic or 'Multi-Tactic'}",
        "description": description,
        "severity": severity,
        "startDate": int(datetime.now(timezone.utc).timestamp() * 1000),
        "tags": tags,
        "flag": severity >= 3,  # flag critical/high cases
        "status": "Open",
        "summary": f"Automated detection: {source_ip} triggered {len(alerts)} SIEM alerts.",
    }


def build_observable(source_ip: str, country: str) -> dict:
    """Build an IP observable for the case."""
    return {
        "dataType": "ip",
        "data": source_ip,
        "message": f"Attacker IP — {country}",
        "tags": ["attacker", "source-ip"],
        "ioc": True,
        "tlp": 2,  # TLP:AMBER
        "pap": 2,  # PAP:AMBER
    }


def create_case(source_ip: str, alerts: list[dict], dry_run: bool) -> Optional[str]:
    """Create a TheHive case for the given source IP cluster."""
    payload = build_case_payload(source_ip, alerts)
    country = alerts[0].get("source.geo.country_code", "??")

    if dry_run:
        print(f"\n  [DRY-RUN] Would create case:")
        print(f"    Title    : {payload['title']}")
        print(f"    Severity : {payload['severity']}")
        print(f"    Tags     : {', '.join(payload['tags'][:5])}...")
        return "dry-run-id"

    try:
        r = requests.post(
            f"{THEHIVE_URL}/api/v1/case",
            headers=thehive_headers(),
            json=payload,
            timeout=10,
        )
        r.raise_for_status()
        case_id = r.json().get("_id", "")

        # Add IP observable
        requests.post(
            f"{THEHIVE_URL}/api/v1/case/{case_id}/observable",
            headers=thehive_headers(),
            json=build_observable(source_ip, country),
            timeout=5,
        )

        print(f"    Case created: {THEHIVE_URL}/cases/{case_id}")
        return case_id

    except ConnectionError:
        print(f"  [WARN] TheHive not reachable at {THEHIVE_URL}.")
        print(f"         Run: soclab thehive up")
        return None
    except Exception as e:
        print(f"  [ERROR] Failed to create case: {e}")
        return None


# ── Main ───────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Mini-SIEM → TheHive integration bot",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--dry-run", action="store_true",
                        help="Show what would be created without calling TheHive API")
    parser.add_argument("--since", default=DEFAULT_SINCE,
                        help="Look back window (e.g. 1h, 24h, 7d). Default: 1h")
    parser.add_argument("--min-severity", default="high",
                        choices=["low", "medium", "high", "critical"],
                        help="Minimum alert severity to process. Default: high")
    parser.add_argument("--loop", action="store_true",
                        help="Run continuously, polling every 5 minutes")
    args = parser.parse_args()

    def run_once() -> None:
        print(f"\n{'='*60}")
        print(f"  Mini-SIEM → TheHive Bot")
        print(f"  {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} UTC")
        print(f"  Since: last {args.since} · Min severity: {args.min_severity}")
        if args.dry_run:
            print(f"  Mode: DRY RUN (no cases will be created)")
        print(f"{'='*60}")

        print(f"\n[1/3] Querying Elasticsearch for alerts...")
        alerts = fetch_alerts(args.since, args.min_severity)

        if not alerts:
            print("  → No alerts found matching criteria.")
            return

        print(f"  → Found {len(alerts)} alerts")

        print(f"\n[2/3] Grouping by source IP...")
        campaigns = group_by_campaign(alerts)
        print(f"  → {len(campaigns)} unique source IPs")

        print(f"\n[3/3] Creating TheHive cases...")
        created = skipped = 0

        for source_ip, ip_alerts in sorted(
            campaigns.items(), key=lambda x: len(x[1]), reverse=True
        ):
            print(f"\n  IP: {source_ip} ({len(ip_alerts)} alerts)")

            if not args.dry_run:
                existing = case_exists(source_ip)
                if existing:
                    print(f"    → Case already exists: {existing} (skipping)")
                    skipped += 1
                    continue

            case_id = create_case(source_ip, ip_alerts, args.dry_run)
            if case_id:
                created += 1

        print(f"\n{'─'*60}")
        print(f"  Cases created: {created}  |  Skipped (existing): {skipped}")
        print(f"  TheHive: {THEHIVE_URL}")
        print(f"  Kibana:  http://localhost:5601")

    if args.loop:
        print("Running in continuous mode (Ctrl+C to stop)...")
        while True:
            run_once()
            print(f"\nNext run in 5 minutes...")
            time.sleep(300)
    else:
        run_once()


if __name__ == "__main__":
    main()
