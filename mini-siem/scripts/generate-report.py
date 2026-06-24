#!/usr/bin/env python3
"""
Weekly Threat Intelligence Report Generator — Mini-SIEM Lab
────────────────────────────────────────────────────────────
Queries Elasticsearch for the past 7 days of SIEM data and produces
a professional Markdown + HTML report suitable for management review.

Output:
    reports/weekly-YYYY-MM-DD.md    (Markdown version)
    reports/weekly-YYYY-MM-DD.html  (HTML version with styling)

Usage:
    python3 scripts/generate-report.py
    python3 scripts/generate-report.py --days 30 --output reports/
    python3 scripts/generate-report.py --format html --open

Requirements:
    pip install requests python-dateutil
"""

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path
from typing import Any

import requests
from requests.exceptions import ConnectionError as ConnError

ES_URL = os.environ.get("ES_URL", "http://localhost:9200")
REPORTS_DIR = Path(__file__).parent.parent / "reports"


# ── Elasticsearch queries ───────────────────────────────────────────────

def es_query(index: str, body: dict) -> dict:
    try:
        r = requests.post(
            f"{ES_URL}/{index}/_search",
            json=body,
            headers={"Content-Type": "application/json"},
            timeout=15,
        )
        r.raise_for_status()
        return r.json()
    except ConnError:
        print(f"[ERROR] Elasticsearch not reachable at {ES_URL}")
        print("        Run 'make up' to start the lab.")
        sys.exit(1)


def es_count(index: str, body: dict) -> int:
    try:
        r = requests.post(
            f"{ES_URL}/{index}/_count",
            json=body,
            headers={"Content-Type": "application/json"},
            timeout=10,
        )
        return r.json().get("count", 0)
    except Exception:
        return 0


def time_range(days: int) -> dict:
    return {"range": {"@timestamp": {"gte": f"now-{days}d", "lt": "now"}}}


def agg_top(field: str, size: int = 10) -> dict:
    return {"terms": {"field": field, "size": size}}


# ── Data collection ────────────────────────────────────────────────────

def collect_stats(days: int) -> dict[str, Any]:
    tr = time_range(days)
    stats: dict[str, Any] = {}

    # Total events across all indexes
    stats["total_events"] = es_count("siem-*", {"query": tr})
    stats["total_alerts"] = es_count("siem-suricata-*", {
        "query": {"bool": {"must": [tr, {"term": {"suricata.event_type": "alert"}}]}}
    })
    stats["total_auth_failures"] = es_count("siem-auth-*", {
        "query": {"bool": {"must": [tr, {"term": {"event.outcome": "failure"}}]}}
    })
    stats["total_auth_success"] = es_count("siem-auth-*", {
        "query": {"bool": {"must": [tr, {"term": {"event.outcome": "success"}}]}}
    })

    # Severity breakdown
    for label in ["CRITICAL", "HIGH", "MEDIUM", "LOW"]:
        stats[f"alerts_{label.lower()}"] = es_count("siem-suricata-*", {
            "query": {"bool": {"must": [tr, {"term": {"alert.severity_label": label}}]}}
        })

    # Top source IPs
    result = es_query("siem-suricata-*,siem-auth-*", {
        "size": 0,
        "query": {"bool": {"must": [tr, {"exists": {"field": "source.ip"}}]}},
        "aggs": {"top_ips": agg_top("source.ip", 10)},
    })
    stats["top_ips"] = result.get("aggregations", {}).get("top_ips", {}).get("buckets", [])

    # Top triggered rules
    result = es_query("siem-suricata-*", {
        "size": 0,
        "query": {"bool": {"must": [tr, {"term": {"suricata.event_type": "alert"}}]}},
        "aggs": {"top_rules": agg_top("suricata.alert.signature.keyword", 10)},
    })
    stats["top_rules"] = result.get("aggregations", {}).get("top_rules", {}).get("buckets", [])

    # Top MITRE techniques
    result = es_query("siem-*", {
        "size": 0,
        "query": {"bool": {"must": [tr, {"exists": {"field": "mitre.technique"}}]}},
        "aggs": {"top_techniques": agg_top("mitre.technique.keyword", 8)},
    })
    stats["top_techniques"] = result.get("aggregations", {}).get("top_techniques", {}).get("buckets", [])

    # Daily trend (per day alert count)
    result = es_query("siem-suricata-*", {
        "size": 0,
        "query": {"bool": {"must": [tr, {"term": {"suricata.event_type": "alert"}}]}},
        "aggs": {
            "daily": {
                "date_histogram": {
                    "field": "@timestamp",
                    "calendar_interval": "day",
                    "format": "yyyy-MM-dd",
                }
            }
        },
    })
    stats["daily_trend"] = result.get("aggregations", {}).get("daily", {}).get("buckets", [])

    # Unique attacker IPs
    result = es_query("siem-suricata-*,siem-auth-*", {
        "size": 0,
        "query": tr,
        "aggs": {"unique_ips": {"cardinality": {"field": "source.ip"}}},
    })
    stats["unique_attacker_ips"] = (
        result.get("aggregations", {}).get("unique_ips", {}).get("value", 0)
    )

    return stats


# ── Report rendering ───────────────────────────────────────────────────

def risk_level(critical: int, high: int, total: int) -> tuple[str, str]:
    if critical >= 5 or (critical >= 1 and high >= 10):
        return "CRITICAL", "🔴"
    if critical >= 1 or high >= 5:
        return "HIGH", "🟠"
    if high >= 1 or total >= 100:
        return "MEDIUM", "🟡"
    return "LOW", "🟢"


def trend_bar(count: int, max_count: int, width: int = 20) -> str:
    if max_count == 0:
        return "░" * width
    filled = round((count / max_count) * width)
    return "█" * filled + "░" * (width - filled)


def render_markdown(stats: dict, days: int, report_date: str) -> str:
    week_num = datetime.now().isocalendar()[1]
    critical = stats.get("alerts_critical", 0)
    high = stats.get("alerts_high", 0)
    total_alerts = stats.get("total_alerts", 0)
    risk, risk_icon = risk_level(critical, high, total_alerts)

    # Daily trend chart
    daily = stats.get("daily_trend", [])
    max_day = max((b["doc_count"] for b in daily), default=1) or 1
    trend_lines = []
    for b in daily[-7:]:
        day = b["key_as_string"]
        count = b["doc_count"]
        bar = trend_bar(count, max_day, 30)
        trend_lines.append(f"  {day}  {bar}  {count:>4}")
    trend_chart = "\n".join(trend_lines) if trend_lines else "  (no data)"

    # Top IPs table
    ip_rows = ""
    for i, b in enumerate(stats.get("top_ips", [])[:5], 1):
        ip_rows += f"| {i} | `{b['key']}` | {b['doc_count']} |\n"
    if not ip_rows:
        ip_rows = "| — | No data | 0 |\n"

    # Top rules table
    rule_rows = ""
    for i, b in enumerate(stats.get("top_rules", [])[:5], 1):
        name = b["key"][:65] + "…" if len(b["key"]) > 65 else b["key"]
        rule_rows += f"| {i} | {name} | {b['doc_count']} |\n"
    if not rule_rows:
        rule_rows = "| — | No data | 0 |\n"

    # MITRE techniques
    technique_rows = ""
    for b in stats.get("top_techniques", [])[:6]:
        technique_rows += f"- **{b['key']}** — {b['doc_count']} events\n"
    if not technique_rows:
        technique_rows = "- No MITRE-tagged events\n"

    # Recommendations
    recs = []
    if critical > 0:
        recs.append(f"🔴 **{critical} critical alert(s) require immediate review** — check Kibana Security → Alerts")
    if stats.get("total_auth_failures", 0) > 50:
        recs.append("⚠️ **High auth failure rate** — consider tightening fail2ban thresholds")
    if high > 10:
        recs.append("⚠️ **Elevated HIGH severity alerts** — run threat hunt H-001 (brute force → success)")
    if not recs:
        recs.append("✅ No immediate actions required — continue monitoring")
    recs_text = "\n".join(f"{r}" for r in recs)

    return f"""# Weekly Threat Intelligence Report
**Week {week_num} — {report_date} | Period: last {days} days**
**Analyst:** Damiano Di Biase | **Lab:** Mini-SIEM (ELK + Suricata)

---

## Executive Summary

| Metric | Value | Status |
|---|---|---|
| Risk Level | **{risk}** | {risk_icon} |
| Total Events | {stats.get('total_events', 0):,} | — |
| Security Alerts | **{total_alerts:,}** | {"🔴" if total_alerts > 200 else "🟡" if total_alerts > 50 else "🟢"} |
| Critical Alerts | {critical} | {"🔴" if critical > 0 else "🟢"} |
| High Alerts | {high} | {"🟠" if high > 5 else "🟢"} |
| Auth Failures | {stats.get('total_auth_failures', 0):,} | — |
| Successful Logins | {stats.get('total_auth_success', 0):,} | — |
| Unique Attacker IPs | {stats.get('unique_attacker_ips', 0)} | — |

---

## Alert Trend (last {min(days, 7)} days)

```
{trend_chart}
```

---

## Top Threat Actors (Source IPs)

| # | IP Address | Alert Count |
|---|---|---|
{ip_rows}
> Run `make enrich-iocs` to get GeoIP + AbuseIPDB reputation for these IPs.

---

## Top Triggered Detection Rules

| # | Rule | Count |
|---|---|---|
{rule_rows}

---

## MITRE ATT&CK Techniques Observed

{technique_rows}
---

## Severity Breakdown

```
CRITICAL  {"█" * min(critical, 20):20s}  {critical}
HIGH      {"█" * min(high, 20):20s}  {high}
MEDIUM    {"█" * min(stats.get("alerts_medium", 0), 20):20s}  {stats.get("alerts_medium", 0)}
LOW       {"█" * min(stats.get("alerts_low", 0), 20):20s}  {stats.get("alerts_low", 0)}
```

---

## Actions Required

{recs_text}

---

## Infrastructure Status

| Component | Status |
|---|---|
| Elasticsearch | {"✅ Online" if stats.get("total_events", 0) > 0 else "❌ No data"} |
| Suricata IDS | {"✅ Active" if stats.get("total_alerts", 0) > 0 else "⚠️ No alerts"} |
| Filebeat | {"✅ Shipping" if stats.get("total_auth_failures", 0) > 0 else "⚠️ No auth data"} |
| Detection Rules | 13 Suricata + 4 Elastic + 4 Sigma |

---

## Next Week Priorities

- [ ] Review all CRITICAL and HIGH alerts from this period
- [ ] Run threat hunt: H-002 (C2 beacon detection)
- [ ] Update threat intel feeds: `make threat-intel`
- [ ] Tune rule SID-9000010 if false positive rate > 20%

---

*Generated by `scripts/generate-report.py` | Mini-SIEM Lab*
*Data source: Elasticsearch `siem-*` indexes | {report_date}*
"""


def render_html(markdown_content: str, report_date: str) -> str:
    rows = []
    in_code = False
    for line in markdown_content.split("\n"):
        if line.startswith("```"):
            in_code = not in_code
            rows.append("<pre>" if in_code else "</pre>")
            continue
        if in_code:
            rows.append(line)
            continue
        if line.startswith("# "):
            rows.append(f"<h1>{line[2:]}</h1>")
        elif line.startswith("## "):
            rows.append(f"<h2>{line[3:]}</h2>")
        elif line.startswith("### "):
            rows.append(f"<h3>{line[4:]}</h3>")
        elif line.startswith("| "):
            if not rows or "<table>" not in rows[-1] and not line.startswith("|---"):
                if not line.startswith("|---"):
                    rows.append('<table><tr>' + "".join(
                        f"<th>{c.strip()}</th>" for c in line.strip("|").split("|")
                    ) + "</tr>")
            elif line.startswith("|---") or line.startswith("| ---"):
                pass
            else:
                rows.append("<tr>" + "".join(
                    f"<td>{c.strip()}</td>" for c in line.strip("|").split("|")
                ) + "</tr>")
        elif line.startswith("- "):
            rows.append(f"<li>{line[2:]}</li>")
        elif line.startswith("---"):
            rows.append("<hr/>")
        elif line.startswith("**") and line.endswith("**"):
            rows.append(f"<strong>{line[2:-2]}</strong>")
        elif line:
            rows.append(f"<p>{line}</p>")
    content = "\n".join(rows)

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Weekly Threat Report — {report_date}</title>
<style>
  :root {{
    --bg: #1a1c21; --bg2: #1e2028; --bg3: #141519;
    --border: #343741; --text: #d1d5db; --muted: #6b7280;
    --accent: #00bfb3; --red: #ef4444; --orange: #f97316;
    --yellow: #eab308; --green: #22c55e; --blue: #60a5fa; --purple: #a78bfa;
  }}
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{ background: var(--bg); color: var(--text); font-family: 'Segoe UI', sans-serif;
          font-size: 14px; line-height: 1.6; padding: 0; }}
  .header {{ background: var(--bg3); border-bottom: 2px solid var(--accent);
             padding: 24px 40px; display: flex; align-items: center; gap: 16px; }}
  .logo {{ width: 36px; height: 36px; background: var(--accent); border-radius: 6px;
           display: flex; align-items: center; justify-content: center;
           font-weight: 700; color: white; font-size: 16px; flex-shrink: 0; }}
  .header h1 {{ font-size: 20px; color: white; }}
  .header p {{ color: var(--muted); font-size: 12px; margin-top: 2px; }}
  .container {{ max-width: 960px; margin: 0 auto; padding: 32px 24px; }}
  h1 {{ font-size: 22px; color: white; margin: 24px 0 8px; border-bottom: 1px solid var(--border); padding-bottom: 8px; }}
  h2 {{ font-size: 16px; color: var(--accent); margin: 28px 0 10px; text-transform: uppercase; letter-spacing: .05em; }}
  h3 {{ font-size: 14px; color: white; margin: 16px 0 8px; }}
  table {{ width: 100%; border-collapse: collapse; margin: 12px 0; background: var(--bg2);
           border-radius: 6px; overflow: hidden; }}
  th {{ background: var(--bg3); color: var(--muted); font-size: 11px; font-weight: 600;
        text-transform: uppercase; padding: 10px 14px; text-align: left; }}
  td {{ padding: 10px 14px; border-top: 1px solid var(--border); }}
  tr:hover td {{ background: #252830; }}
  pre {{ background: var(--bg3); border: 1px solid var(--border); border-radius: 6px;
         padding: 16px; font-family: 'Consolas', monospace; font-size: 12px;
         color: #34d399; overflow-x: auto; margin: 12px 0; }}
  p {{ color: var(--text); margin: 6px 0; }}
  li {{ margin: 4px 0 4px 20px; color: var(--text); }}
  li:before {{ content: "•"; color: var(--accent); margin-right: 8px; }}
  hr {{ border: none; border-top: 1px solid var(--border); margin: 20px 0; }}
  strong {{ color: white; font-weight: 600; }}
  .footer {{ background: var(--bg3); border-top: 1px solid var(--border);
             padding: 16px 40px; color: var(--muted); font-size: 11px;
             display: flex; justify-content: space-between; margin-top: 40px; }}
</style>
</head>
<body>
<div class="header">
  <div class="logo">ES</div>
  <div>
    <h1>Weekly Threat Intelligence Report</h1>
    <p>Mini-SIEM Lab · Damiano Di Biase · {report_date}</p>
  </div>
</div>
<div class="container">
{content}
</div>
<div class="footer">
  <span>Mini-SIEM Lab — Elasticsearch + Suricata + Filebeat</span>
  <span>Generated: {report_date}</span>
</div>
</body>
</html>"""


# ── Entry point ─────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description="Generate weekly SIEM threat report")
    parser.add_argument("--days", type=int, default=7, help="Reporting period in days (default: 7)")
    parser.add_argument("--output", default=str(REPORTS_DIR), help="Output directory")
    parser.add_argument("--format", choices=["md", "html", "both"], default="both")
    parser.add_argument("--open", action="store_true", help="Open HTML report in browser")
    args = parser.parse_args()

    report_date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    out_dir = Path(args.output)
    out_dir.mkdir(parents=True, exist_ok=True)

    print(f"\n{'='*60}")
    print(f"  Weekly Threat Report Generator — Mini-SIEM Lab")
    print(f"  Period: last {args.days} days | Date: {report_date}")
    print(f"{'='*60}\n")

    print("[1/3] Collecting data from Elasticsearch...")
    stats = collect_stats(args.days)

    total = stats.get("total_events", 0)
    alerts = stats.get("total_alerts", 0)
    print(f"  Total events: {total:,}  |  Alerts: {alerts:,}  |  Unique IPs: {stats.get('unique_attacker_ips', 0)}")

    print("\n[2/3] Rendering report...")
    md_content = render_markdown(stats, args.days, report_date)

    saved = []

    if args.format in ("md", "both"):
        md_path = out_dir / f"weekly-{report_date}.md"
        md_path.write_text(md_content, encoding="utf-8")
        saved.append(str(md_path))
        print(f"  Markdown: {md_path}")

    if args.format in ("html", "both"):
        html_content = render_html(md_content, report_date)
        html_path = out_dir / f"weekly-{report_date}.html"
        html_path.write_text(html_content, encoding="utf-8")
        saved.append(str(html_path))
        print(f"  HTML:     {html_path}")

    print("\n[3/3] Done.")
    risk, icon = risk_level(
        stats.get("alerts_critical", 0),
        stats.get("alerts_high", 0),
        stats.get("total_alerts", 0),
    )
    print(f"\n  {'─'*40}")
    print(f"  Overall Risk: {icon}  {risk}")
    print(f"  Alerts:       {alerts:,}  (Critical: {stats.get('alerts_critical', 0)}, High: {stats.get('alerts_high', 0)})")
    print(f"  {'─'*40}")

    if args.open and saved:
        html_files = [f for f in saved if f.endswith(".html")]
        if html_files:
            subprocess.Popen(["xdg-open" if sys.platform == "linux" else "open", html_files[0]])


if __name__ == "__main__":
    main()
