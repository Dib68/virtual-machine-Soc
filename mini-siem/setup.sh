#!/usr/bin/env bash
# ============================================================
#  Mini-SIEM Lab — One-Command Setup
#  ───────────────────────────────────
#  Checks prerequisites, starts the full stack, waits for
#  health, loads threat intel feeds, and prints a summary.
#
#  Usage:
#    chmod +x setup.sh && ./setup.sh
#    ./setup.sh --skip-threat-intel   (faster, no feed download)
#    ./setup.sh --pull                (pre-pull Docker images)
# ============================================================
set -euo pipefail

RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'
BLU='\033[0;34m'; CYN='\033[0;36m'; BLD='\033[1m'; NC='\033[0m'

SKIP_TI="${1:-}"
PULL_IMAGES="${2:-}"
START_TS=$(date +%s)

print_banner() {
  echo -e "${CYN}"
  echo "  ███╗   ███╗██╗███╗   ██╗██╗    ███████╗██╗███████╗███╗   ███╗"
  echo "  ████╗ ████║██║████╗  ██║██║    ██╔════╝██║██╔════╝████╗ ████║"
  echo "  ██╔████╔██║██║██╔██╗ ██║██║    ███████╗██║█████╗  ██╔████╔██║"
  echo "  ██║╚██╔╝██║██║██║╚██╗██║██║    ╚════██║██║██╔══╝  ██║╚██╔╝██║"
  echo "  ██║ ╚═╝ ██║██║██║ ╚████║██║    ███████║██║███████╗██║ ╚═╝ ██║"
  echo "  ╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝╚═╝    ╚══════╝╚═╝╚══════╝╚═╝     ╚═╝"
  echo -e "${NC}"
  echo -e "  ${BLD}Threat Detection Lab${NC} — ELK 8.14 + Suricata + MITRE ATT&CK"
  echo -e "  https://github.com/Dib68/virtual-machine-Soc"
  echo ""
}

step() { echo -e "${BLU}[$(date '+%H:%M:%S')]${NC} ${BLD}$1${NC}"; }
ok()   { echo -e "  ${GRN}✓${NC} $1"; }
warn() { echo -e "  ${YLW}⚠${NC}  $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }
die()  { echo -e "\n${RED}ERROR: $1${NC}\n"; exit 1; }

# ── 1. Banner ─────────────────────────────────────────────
print_banner

# ── 2. Prerequisites ─────────────────────────────────────
step "Checking prerequisites..."

# Docker
if ! command -v docker &>/dev/null; then
  die "Docker not found. Install from: https://docs.docker.com/get-docker/"
fi
DOCKER_VER=$(docker --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
ok "Docker $DOCKER_VER"

# Docker Compose
if ! docker compose version &>/dev/null; then
  die "Docker Compose v2 not found. Update Docker or install compose plugin."
fi
COMPOSE_VER=$(docker compose version --short 2>/dev/null || echo "v2")
ok "Docker Compose $COMPOSE_VER"

# Memory check (need at least 4 GB)
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  TOTAL_MEM_GB=$(( TOTAL_MEM_KB / 1024 / 1024 ))
  if [ "$TOTAL_MEM_GB" -lt 4 ]; then
    die "Insufficient RAM: ${TOTAL_MEM_GB}GB available, 4GB required. Elasticsearch needs at least 2GB heap."
  fi
  ok "Memory: ${TOTAL_MEM_GB}GB available (min 4GB required)"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  TOTAL_MEM_GB=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))
  [ "$TOTAL_MEM_GB" -lt 4 ] && die "Insufficient RAM: ${TOTAL_MEM_GB}GB available, 4GB required."
  ok "Memory: ${TOTAL_MEM_GB}GB available"
fi

# Disk space check (need at least 10 GB)
AVAIL_DISK_GB=$(df -BG . | awk 'NR==2 {gsub("G",""); print $4}')
if [ "${AVAIL_DISK_GB:-0}" -lt 10 ]; then
  warn "Low disk space: ${AVAIL_DISK_GB}GB available (10GB recommended for ELK data)"
else
  ok "Disk: ${AVAIL_DISK_GB}GB available"
fi

# vm.max_map_count (Elasticsearch requirement on Linux)
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  MAP_COUNT=$(sysctl -n vm.max_map_count 2>/dev/null || echo 0)
  if [ "$MAP_COUNT" -lt 262144 ]; then
    warn "vm.max_map_count=$MAP_COUNT (Elasticsearch needs 262144)"
    echo -e "  ${YLW}Auto-fixing: sudo sysctl -w vm.max_map_count=262144${NC}"
    sudo sysctl -w vm.max_map_count=262144 &>/dev/null && ok "vm.max_map_count set to 262144" || \
      warn "Could not set vm.max_map_count — run: sudo sysctl -w vm.max_map_count=262144"
  else
    ok "vm.max_map_count=$MAP_COUNT"
  fi
fi

# Python3 (for scripts)
if command -v python3 &>/dev/null; then
  PY_VER=$(python3 --version | awk '{print $2}')
  ok "Python $PY_VER"
else
  warn "Python3 not found — report generator and SOAR bot will not work"
fi

# ── 3. Environment setup ─────────────────────────────────
echo ""
step "Setting up environment..."

if [ ! -f ".env" ]; then
  if [ -f ".env.example" ]; then
    cp .env.example .env
    ok "Created .env from .env.example"
    warn "Review .env and add API keys for AbuseIPDB, TheHive, etc."
  fi
else
  ok ".env exists"
fi

# Install Python dependencies (if pip available)
if command -v pip3 &>/dev/null && [ -f "requirements.txt" ]; then
  echo -e "  ${BLU}Installing Python dependencies...${NC}"
  pip3 install -q -r requirements.txt && ok "Python packages installed" || \
    warn "pip3 install failed — run: pip3 install -r requirements.txt"
fi

# Create reports directory
mkdir -p reports
ok "reports/ directory ready"

# ── 4. Optional image pre-pull ────────────────────────────
if [ "$PULL_IMAGES" = "--pull" ]; then
  echo ""
  step "Pre-pulling Docker images (this may take a few minutes)..."
  docker compose pull && ok "All images pulled"
fi

# ── 5. Start the stack ───────────────────────────────────
echo ""
step "Starting Mini-SIEM stack..."
docker compose up -d
ok "Stack started (7 containers)"

# ── 6. Wait for Elasticsearch ────────────────────────────
echo ""
step "Waiting for Elasticsearch to be healthy..."
ES_URL="http://localhost:9200"
MAX_WAIT=120
ELAPSED=0
echo -n "  "
while true; do
  if curl -sf "${ES_URL}/_cluster/health" &>/dev/null; then
    STATUS=$(curl -sf "${ES_URL}/_cluster/health" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','unknown'))" 2>/dev/null || echo "unknown")
    echo ""
    if [ "$STATUS" = "green" ] || [ "$STATUS" = "yellow" ]; then
      ok "Elasticsearch healthy (status: $STATUS)"
      break
    fi
  fi
  if [ "$ELAPSED" -ge "$MAX_WAIT" ]; then
    echo ""
    die "Elasticsearch did not become healthy in ${MAX_WAIT}s. Check: docker compose logs elasticsearch"
  fi
  echo -n "."
  sleep 5
  ELAPSED=$((ELAPSED + 5))
done

# ── 7. Wait for Kibana ───────────────────────────────────
step "Waiting for Kibana to be available..."
KIBANA_URL="http://localhost:5601"
ELAPSED=0
echo -n "  "
while true; do
  HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" "${KIBANA_URL}/api/status" 2>/dev/null || echo "000")
  if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
    echo ""
    ok "Kibana available"
    break
  fi
  if [ "$ELAPSED" -ge 120 ]; then
    echo ""
    warn "Kibana not ready yet — it may still be initializing (check: docker compose logs kibana)"
    break
  fi
  echo -n "."
  sleep 5
  ELAPSED=$((ELAPSED + 5))
done

# ── 8. Threat Intel Feeds ────────────────────────────────
if [ "$SKIP_TI" != "--skip-threat-intel" ]; then
  echo ""
  step "Syncing threat intelligence feeds..."
  if bash scripts/threat-intel-sync.sh &>/dev/null; then
    RULE_COUNT=$(grep -c '^alert\|^drop' config/suricata/rules/threat-intel.rules 2>/dev/null || echo 0)
    ok "Threat intel rules loaded ($RULE_COUNT rules from live feeds)"
  else
    warn "Threat intel sync failed — run manually: make threat-intel"
  fi
else
  warn "Skipping threat intel sync (--skip-threat-intel)"
fi

# ── 9. Validate stack ────────────────────────────────────
echo ""
step "Validating stack health..."

ES_DOCS=$(curl -sf "${ES_URL}/_count" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('count',0))" 2>/dev/null || echo "0")
ok "Elasticsearch: ${ES_DOCS} documents indexed"

RUNNING=$(docker compose ps --status running 2>/dev/null | grep -c "running" || echo "0")
ok "$RUNNING / 7 containers running"

# ── 10. Summary ──────────────────────────────────────────
END_TS=$(date +%s)
ELAPSED_TOTAL=$((END_TS - START_TS))

echo ""
echo -e "${GRN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${BLD}${GRN}Mini-SIEM Lab is ready!${NC}  (setup time: ${ELAPSED_TOTAL}s)"
echo -e "${GRN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${BLD}Access points:${NC}"
echo -e "  Kibana SIEM     →  ${CYN}http://localhost:5601${NC}"
echo -e "  Elasticsearch   →  ${CYN}http://localhost:9200${NC}"
echo -e "  Target SSH      →  ${CYN}ssh labuser@localhost -p 2222${NC}  (pass: labpass)"
echo -e "  Target HTTP     →  ${CYN}http://localhost:8080${NC}"
echo ""
echo -e "  ${BLD}Quick start:${NC}"
echo -e "  ${YLW}make attack-all${NC}    # Run all 4 attack simulations"
echo -e "  ${YLW}make check${NC}         # View alert summary"
echo -e "  ${YLW}make report${NC}        # Generate weekly threat report"
echo -e "  ${YLW}make soar-bot-dry${NC}  # Preview SOAR automation"
echo ""
echo -e "  ${BLD}Full walkthrough:${NC}  ${BLU}docs/WALKTHROUGH.md${NC}"
echo -e "  ${BLD}Hunting queries:${NC}   ${BLU}docs/hunting/eql-queries.md${NC}"
echo -e "  ${BLD}All commands:${NC}      ${YLW}make help${NC}"
echo ""
