#!/usr/bin/env python3
"""
IOC Lookup Tool — Mini-SIEM Lab
────────────────────────────────
Multi-source threat intelligence lookup for IPs, domains, and file hashes.
Queries multiple free APIs and produces a consolidated risk assessment.

Sources:
  AbuseIPDB    — IP reputation (confidence score, abuse reports)
  ip-api.com   — GeoIP + ASN (no key required)
  VirusTotal   — IP/domain/hash reputation (free 4 req/min)
  Shodan       — Open ports, banners, CVEs (free tier)

Usage:
  python3 scripts/ioc-lookup.py 198.51.100.1
  python3 scripts/ioc-lookup.py evil-domain.com
  python3 scripts/ioc-lookup.py d41d8cd98f00b204e9800998ecf8427e
  python3 scripts/ioc-lookup.py 198.51.100.1 --json
  python3 scripts/ioc-lookup.py 198.51.100.1 --save reports/ioc-198.51.100.1.json
  cat ips.txt | python3 scripts/ioc-lookup.py --bulk

Requirements:
  pip install requests rich
  ABUSEIPDB_API_KEY, VIRUSTOTAL_API_KEY, SHODAN_API_KEY  (in .env or env vars)

Free tier limits:
  AbuseIPDB: 1000 checks/day     → https://www.abuseipdb.com/api
  VirusTotal: 4 req/min, 500/day → https://www.virustotal.com/gui/join-us
  ip-api.com: 45 req/min         → no registration needed
  Shodan:     1 req/sec          → https://account.shodan.io/register
"""

import argparse
import ipaddress
import json
import os
import re
import sys
import time
from pathlib import Path
from typing import Any

import requests

try:
    from rich.console import Console
    from rich.table import Table
    from rich.panel import Panel
    from rich import box
    RICH = True
    console = Console()
except ImportError:
    RICH = False
    class _Console:
        def print(self, *args, **kwargs): print(*args)
    console = _Console()

# ── Configuration ───────────────────────────────────────────────────────
ABUSEIPDB_KEY  = os.environ.get("ABUSEIPDB_API_KEY", "")
VT_KEY         = os.environ.get("VIRUSTOTAL_API_KEY", "")
SHODAN_KEY     = os.environ.get("SHODAN_API_KEY", "")

TIMEOUT = 10
HEADERS = {"User-Agent": "MiniSIEM-IOC-Lookup/1.0 (SOC Lab Tool)"}


# ── IOC type detection ──────────────────────────────────────────────────

def detect_ioc_type(ioc: str) -> str:
    ioc = ioc.strip()
    # IPv4
    try:
        ipaddress.IPv4Address(ioc)
        return "ipv4"
    except ValueError:
        pass
    # IPv6
    try:
        ipaddress.IPv6Address(ioc)
        return "ipv6"
    except ValueError:
        pass
    # MD5 / SHA1 / SHA256 hash
    if re.match(r'^[0-9a-fA-F]{32}$', ioc):
        return "md5"
    if re.match(r'^[0-9a-fA-F]{40}$', ioc):
        return "sha1"
    if re.match(r'^[0-9a-fA-F]{64}$', ioc):
        return "sha256"
    # Domain
    if re.match(r'^(?:[a-z0-9](?:[a-z0-9\-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$', ioc, re.I):
        return "domain"
    # URL
    if ioc.startswith(("http://", "https://")):
        return "url"
    return "unknown"


# ── API wrappers ────────────────────────────────────────────────────────

def lookup_ip_api(ip: str) -> dict:
    """GeoIP + ASN lookup via ip-api.com (no key, 45 req/min)"""
    try:
        r = requests.get(
            f"http://ip-api.com/json/{ip}",
            params={"fields": "status,country,countryCode,regionName,city,isp,org,as,reverse,mobile,proxy,hosting,query"},
            timeout=TIMEOUT,
            headers=HEADERS,
        )
        data = r.json()
        if data.get("status") == "success":
            return {
                "source": "ip-api.com",
                "country": f"{data.get('country', '?')} ({data.get('countryCode', '?')})",
                "region": f"{data.get('city', '?')}, {data.get('regionName', '?')}",
                "isp": data.get("isp", "?"),
                "org": data.get("org", "?"),
                "asn": data.get("as", "?"),
                "reverse_dns": data.get("reverse", ""),
                "is_proxy": data.get("proxy", False),
                "is_hosting": data.get("hosting", False),
                "is_mobile": data.get("mobile", False),
            }
    except Exception as e:
        return {"source": "ip-api.com", "error": str(e)}
    return {"source": "ip-api.com", "error": "no data"}


def lookup_abuseipdb(ip: str) -> dict:
    """AbuseIPDB reputation check"""
    if not ABUSEIPDB_KEY:
        return {"source": "AbuseIPDB", "error": "No API key (set ABUSEIPDB_API_KEY)"}
    try:
        r = requests.get(
            "https://api.abuseipdb.com/api/v2/check",
            params={"ipAddress": ip, "maxAgeInDays": 90, "verbose": True},
            headers={**HEADERS, "Key": ABUSEIPDB_KEY, "Accept": "application/json"},
            timeout=TIMEOUT,
        )
        data = r.json().get("data", {})
        return {
            "source": "AbuseIPDB",
            "confidence_score": data.get("abuseConfidenceScore", 0),
            "total_reports": data.get("totalReports", 0),
            "distinct_users": data.get("numDistinctUsers", 0),
            "last_reported": data.get("lastReportedAt", "never"),
            "is_tor": data.get("isTor", False),
            "usage_type": data.get("usageType", "?"),
            "isp": data.get("isp", "?"),
            "country": data.get("countryCode", "?"),
            "recent_categories": list(set([
                r.get("categories", [None])[0] for r in data.get("reports", [])[:5]
                if r.get("categories")
            ])),
        }
    except Exception as e:
        return {"source": "AbuseIPDB", "error": str(e)}


def lookup_virustotal_ip(ip: str) -> dict:
    """VirusTotal IP reputation"""
    if not VT_KEY:
        return {"source": "VirusTotal", "error": "No API key (set VIRUSTOTAL_API_KEY)"}
    try:
        r = requests.get(
            f"https://www.virustotal.com/api/v3/ip_addresses/{ip}",
            headers={**HEADERS, "x-apikey": VT_KEY},
            timeout=TIMEOUT,
        )
        data = r.json().get("data", {}).get("attributes", {})
        stats = data.get("last_analysis_stats", {})
        return {
            "source": "VirusTotal",
            "malicious": stats.get("malicious", 0),
            "suspicious": stats.get("suspicious", 0),
            "harmless": stats.get("harmless", 0),
            "undetected": stats.get("undetected", 0),
            "network": data.get("network", "?"),
            "country": data.get("country", "?"),
            "asn": data.get("asn", "?"),
            "as_owner": data.get("as_owner", "?"),
            "reputation": data.get("reputation", 0),
            "tags": data.get("tags", []),
        }
    except Exception as e:
        return {"source": "VirusTotal", "error": str(e)}


def lookup_virustotal_hash(hash_val: str) -> dict:
    """VirusTotal file hash lookup"""
    if not VT_KEY:
        return {"source": "VirusTotal", "error": "No API key (set VIRUSTOTAL_API_KEY)"}
    try:
        r = requests.get(
            f"https://www.virustotal.com/api/v3/files/{hash_val}",
            headers={**HEADERS, "x-apikey": VT_KEY},
            timeout=TIMEOUT,
        )
        data = r.json().get("data", {}).get("attributes", {})
        stats = data.get("last_analysis_stats", {})
        return {
            "source": "VirusTotal",
            "name": data.get("meaningful_name", "?"),
            "type": data.get("type_description", "?"),
            "size": data.get("size", 0),
            "malicious": stats.get("malicious", 0),
            "suspicious": stats.get("suspicious", 0),
            "harmless": stats.get("harmless", 0),
            "first_seen": data.get("first_submission_date", "?"),
            "last_seen": data.get("last_submission_date", "?"),
            "names": data.get("names", [])[:5],
            "tags": data.get("tags", []),
        }
    except Exception as e:
        return {"source": "VirusTotal", "error": str(e)}


def lookup_shodan(ip: str) -> dict:
    """Shodan host lookup"""
    if not SHODAN_KEY:
        return {"source": "Shodan", "error": "No API key (set SHODAN_API_KEY)"}
    try:
        r = requests.get(
            f"https://api.shodan.io/shodan/host/{ip}",
            params={"key": SHODAN_KEY},
            timeout=TIMEOUT,
        )
        if r.status_code == 404:
            return {"source": "Shodan", "error": "IP not in Shodan database"}
        data = r.json()
        ports = sorted(set([s.get("port") for s in data.get("data", [])]))[:20]
        vulns = list(data.get("vulns", {}).keys())[:10]
        return {
            "source": "Shodan",
            "org": data.get("org", "?"),
            "isp": data.get("isp", "?"),
            "country": data.get("country_name", "?"),
            "city": data.get("city", "?"),
            "os": data.get("os", "?"),
            "open_ports": ports,
            "hostnames": data.get("hostnames", [])[:5],
            "domains": data.get("domains", [])[:5],
            "vulns": vulns,
            "last_update": data.get("last_update", "?"),
            "tags": data.get("tags", []),
        }
    except Exception as e:
        return {"source": "Shodan", "error": str(e)}


# ── Risk scoring ────────────────────────────────────────────────────────

def calculate_risk(results: dict) -> tuple[int, str, str]:
    score = 0

    abuse = results.get("abuseipdb", {})
    if not abuse.get("error"):
        score += min(abuse.get("confidence_score", 0), 60)
        if abuse.get("is_tor"):
            score += 20
        if abuse.get("total_reports", 0) > 100:
            score += 10

    vt = results.get("virustotal", {})
    if not vt.get("error"):
        malicious = vt.get("malicious", 0)
        score += min(malicious * 3, 40)

    geo = results.get("geo", {})
    if not geo.get("error"):
        if geo.get("is_proxy"):
            score += 10
        if geo.get("is_hosting"):
            score += 5

    shodan = results.get("shodan", {})
    if not shodan.get("error"):
        if shodan.get("vulns"):
            score += 15

    score = min(score, 100)

    if score >= 75:
        return score, "CRITICAL", "red"
    if score >= 50:
        return score, "HIGH", "orange"
    if score >= 25:
        return score, "MEDIUM", "yellow"
    return score, "LOW", "green"


# ── Output formatting ────────────────────────────────────────────────────

def print_results(ioc: str, ioc_type: str, results: dict) -> None:
    score, level, color = calculate_risk(results)

    if RICH:
        risk_color = {"red": "red", "orange": "orange1", "yellow": "yellow", "green": "green"}[color]

        console.print()
        console.print(Panel(
            f"[bold]{ioc}[/bold]\n"
            f"Type: [cyan]{ioc_type}[/cyan]  |  "
            f"Risk: [bold {risk_color}]{level}[/bold {risk_color}]  |  "
            f"Score: [bold {risk_color}]{score}/100[/bold {risk_color}]",
            title="[bold]IOC Analysis Report[/bold]",
            border_style="blue",
        ))

        # GeoIP
        geo = results.get("geo", {})
        if geo and not geo.get("error"):
            t = Table(title="[bold]GeoIP / ASN[/bold]", box=box.SIMPLE, show_header=False)
            t.add_column("Field", style="dim", width=18)
            t.add_column("Value")
            t.add_row("Country", geo.get("country", "?"))
            t.add_row("Region", geo.get("region", "?"))
            t.add_row("ISP", geo.get("isp", "?"))
            t.add_row("ASN", geo.get("asn", "?"))
            t.add_row("Reverse DNS", geo.get("reverse_dns", "") or "(none)")
            t.add_row("Proxy/Hosting", f"proxy={geo.get('is_proxy')}, hosting={geo.get('is_hosting')}")
            console.print(t)

        # AbuseIPDB
        abuse = results.get("abuseipdb", {})
        if abuse and not abuse.get("error"):
            conf = abuse.get("confidence_score", 0)
            conf_color = "red" if conf > 50 else "yellow" if conf > 10 else "green"
            t = Table(title="[bold]AbuseIPDB[/bold]", box=box.SIMPLE, show_header=False)
            t.add_column("Field", style="dim", width=18)
            t.add_column("Value")
            t.add_row("Confidence", f"[{conf_color}]{conf}%[/{conf_color}]")
            t.add_row("Total Reports", str(abuse.get("total_reports", 0)))
            t.add_row("Distinct Users", str(abuse.get("distinct_users", 0)))
            t.add_row("Last Reported", str(abuse.get("last_reported", "never")))
            t.add_row("Tor Exit Node", str(abuse.get("is_tor", False)))
            t.add_row("Usage Type", abuse.get("usage_type", "?"))
            console.print(t)
        elif abuse.get("error"):
            console.print(f"[dim]AbuseIPDB: {abuse['error']}[/dim]")

        # VirusTotal
        vt = results.get("virustotal", {})
        if vt and not vt.get("error"):
            mal = vt.get("malicious", 0)
            mal_color = "red" if mal > 5 else "yellow" if mal > 0 else "green"
            t = Table(title="[bold]VirusTotal[/bold]", box=box.SIMPLE, show_header=False)
            t.add_column("Field", style="dim", width=18)
            t.add_column("Value")
            t.add_row("Malicious", f"[{mal_color}]{mal} engines[/{mal_color}]")
            t.add_row("Suspicious", str(vt.get("suspicious", 0)))
            t.add_row("Harmless", str(vt.get("harmless", 0)))
            if "name" in vt:
                t.add_row("File Name", vt.get("name", "?"))
                t.add_row("File Type", vt.get("type", "?"))
            t.add_row("Tags", ", ".join(vt.get("tags", [])) or "(none)")
            console.print(t)
        elif vt.get("error"):
            console.print(f"[dim]VirusTotal: {vt['error']}[/dim]")

        # Shodan
        shodan = results.get("shodan", {})
        if shodan and not shodan.get("error"):
            t = Table(title="[bold]Shodan[/bold]", box=box.SIMPLE, show_header=False)
            t.add_column("Field", style="dim", width=18)
            t.add_column("Value")
            t.add_row("Open Ports", ", ".join(str(p) for p in shodan.get("open_ports", [])) or "(none)")
            t.add_row("OS", shodan.get("os") or "?")
            if shodan.get("vulns"):
                t.add_row("CVEs", "[red]" + ", ".join(shodan["vulns"][:5]) + "[/red]")
            t.add_row("Tags", ", ".join(shodan.get("tags", [])) or "(none)")
            console.print(t)
        elif shodan.get("error"):
            console.print(f"[dim]Shodan: {shodan['error']}[/dim]")

    else:
        # Plain text fallback
        print(f"\n{'='*60}")
        print(f"  IOC: {ioc}  |  Type: {ioc_type}")
        print(f"  Risk: {level}  |  Score: {score}/100")
        print(f"{'='*60}")
        for source, data in results.items():
            print(f"\n[{source.upper()}]")
            if isinstance(data, dict):
                for k, v in data.items():
                    if k != "source":
                        print(f"  {k}: {v}")


# ── Main ─────────────────────────────────────────────────────────────────

def lookup_ioc(ioc: str) -> dict[str, Any]:
    ioc = ioc.strip()
    ioc_type = detect_ioc_type(ioc)

    results: dict[str, Any] = {"ioc": ioc, "type": ioc_type}

    if ioc_type in ("ipv4", "ipv6"):
        results["geo"] = lookup_ip_api(ioc)
        time.sleep(0.2)  # ip-api rate limit
        results["abuseipdb"] = lookup_abuseipdb(ioc)
        results["virustotal"] = lookup_virustotal_ip(ioc)
        results["shodan"] = lookup_shodan(ioc)
    elif ioc_type in ("md5", "sha1", "sha256"):
        results["virustotal"] = lookup_virustotal_hash(ioc)
    elif ioc_type == "domain":
        results["virustotal"] = lookup_virustotal_ip(ioc)
    else:
        print(f"Unknown IOC type for: {ioc}", file=sys.stderr)

    score, level, _ = calculate_risk(results)
    results["risk_score"] = score
    results["risk_level"] = level

    return results


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Multi-source IOC lookup tool — Mini-SIEM Lab",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 scripts/ioc-lookup.py 198.51.100.1
  python3 scripts/ioc-lookup.py evil.example.com --json
  python3 scripts/ioc-lookup.py d41d8cd98f00b204e9800998ecf8427e
  echo -e "1.2.3.4\\n5.6.7.8" | python3 scripts/ioc-lookup.py --bulk
        """
    )
    parser.add_argument("ioc", nargs="?", help="IP, domain, or file hash to look up")
    parser.add_argument("--json", action="store_true", help="Output raw JSON")
    parser.add_argument("--save", help="Save JSON results to file")
    parser.add_argument("--bulk", action="store_true", help="Read IOCs from stdin (one per line)")
    args = parser.parse_args()

    if args.bulk:
        iocs = [line.strip() for line in sys.stdin if line.strip() and not line.startswith("#")]
    elif args.ioc:
        iocs = [args.ioc]
    else:
        parser.print_help()
        sys.exit(1)

    all_results = []
    for ioc in iocs:
        if not ioc:
            continue
        results = lookup_ioc(ioc)

        if args.json:
            print(json.dumps(results, indent=2, default=str))
        else:
            print_results(ioc, results.get("type", "?"), results)

        all_results.append(results)

        # Rate limit between lookups
        if len(iocs) > 1:
            time.sleep(1)

    if args.save:
        out = Path(args.save)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(all_results, indent=2, default=str), encoding="utf-8")
        print(f"\nResults saved to: {out}")


if __name__ == "__main__":
    main()
