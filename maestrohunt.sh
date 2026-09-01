#!/bin/bash
# MaestroHunt - Automated Bug Bounty Recon Pipeline
# Usage: ./maestrohunt.sh [domain] [--config config.conf]

set -euo pipefail

# --- Load Configuration ---
CONFIG_FILE="${2:-config.conf}"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "[!] Configuration file not found. Copy config.conf.example and edit."
    exit 1
fi

DOMAIN="${1:-$DOMAIN}"
if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 <domain> [--config config.conf]"
    exit 1
fi

# --- Setup Directories ---
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BASE_DIR="${BASE_DIR:-$HOME/bugbounty}"
TARGET_DIR="$BASE_DIR/$DOMAIN/$TIMESTAMP"
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR" || exit 1

# --- Logging function ---
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "maestrohunt.log"
}

# --- Tool check ---
check_tool() {
    if ! command -v "$1" &>/dev/null; then
        log "[!] $1 not found. Please install it."
        return 1
    fi
    return 0
}

# ====================
# Phase Functions
# ====================

phase_osint() {
    log "===== Phase 1: OSINT & Setup ====="
    whois "$DOMAIN" > "whois.txt" 2>/dev/null || true
    dig "$DOMAIN" ANY > "dig.txt" 2>/dev/null || true
    log "OSINT data saved."
}

phase_passive() {
    log "===== Phase 2: Passive Subdomain Enumeration ====="
    check_tool subfinder || return 1
    check_tool assetfinder || return 1
    check_tool amass || return 1

    subfinder -d "$DOMAIN" -silent -o "subfinder.txt"
    assetfinder --subs-only "$DOMAIN" > "assetfinder.txt"
    amass enum -passive -d "$DOMAIN" -o "amass.txt" 2>/dev/null

    cat subfinder.txt assetfinder.txt amass.txt 2>/dev/null | sort -u > "passive_subs.txt"
    log "Passive subdomains found: $(wc -l < passive_subs.txt)"
}

phase_active() {
    log "===== Phase 3: Active Subdomain Enumeration ====="
    check_tool puredns || { log "Skipping active (puredns not found)"; return 0; }

    if [ -f "$RESOLVERS_FILE" ]; then
        puredns bruteforce "$SECLISTS_DIR/Discovery/DNS/subdomains-top1million-5000.txt" \
            "$DOMAIN" -r "$RESOLVERS_FILE" -w "active_subs.txt" 2>/dev/null
    else
        log "Resolvers file not found, skipping active brute force."
    fi

    cat passive_subs.txt active_subs.txt 2>/dev/null | sort -u > "all_subs.txt"
    log "Total subdomains: $(wc -l < all_subs.txt)"
}

phase_live() {
    log "===== Phase 4: Live Host Discovery ====="
    check_tool httpx || return 1
    httpx -l all_subs.txt -silent -status-code -title -tech-detect -threads "$THREADS" \
        -o "live_hosts.txt" 2>/dev/null
    log "Live hosts: $(wc -l < live_hosts.txt)"

    if command -v naabu &>/dev/null && [ "${ENABLE_PORTSCAN:-1}" -eq 1 ]; then
        log "Running port scan on live hosts..."
        naabu -list live_hosts.txt -top-ports 1000 -silent -o "open_ports.txt" 2>/dev/null
    fi
}

phase_web() {
    log "===== Phase 5: Web Tech & Endpoint Discovery ====="
    check_tool katana || { log "katana not found, skipping crawl"; return 0; }
    check_tool gau || { log "gau not found, skipping archive"; }
    check_tool waybackurls || { log "waybackurls not found, skipping"; }

    katana -list live_hosts.txt -silent -o "crawled_urls.txt" 2>/dev/null
    gau "$DOMAIN" > "gau_urls.txt" 2>/dev/null
    waybackurls "$DOMAIN" > "wayback_urls.txt" 2>/dev/null

    cat crawled_urls.txt gau_urls.txt wayback_urls.txt 2>/dev/null | sort -u > "all_urls.txt"
    grep -E "\.js$" all_urls.txt > "js_files.txt" 2>/dev/null
    log "Total URLs: $(wc -l < all_urls.txt)"
}

phase_param() {
    log "===== Phase 6: Parameter Discovery ====="
    check_tool arjun || { log "arjun not found, skipping"; return 0; }
    head -n 200 all_urls.txt > "urls_for_param.txt"
    arjun -i urls_for_param.txt -t "$THREADS" -o "params.txt" 2>/dev/null
    log "Parameters found: $(wc -l < params.txt 2>/dev/null || echo 0)"
}

phase_vuln() {
    log "===== Phase 7: Vulnerability Scanning ====="
    check_tool nuclei || { log "nuclei not found, skipping"; return 0; }
    check_tool gf || { log "gf not found, skipping pattern matching"; }

    nuclei -l live_hosts.txt -t "$NUCLEI_TEMPLATES" -severity low,medium,high,critical \
        -threads "$THREADS" -o "nuclei_results.txt" 2>/dev/null

    if command -v gf &>/dev/null; then
        cat all_urls.txt | gf xss > "potential_xss.txt"
        cat all_urls.txt | gf sqli > "potential_sqli.txt"
        cat all_urls.txt | gf lfi > "potential_lfi.txt"
        cat all_urls.txt | gf redirect > "potential_open_redirect.txt"
        log "GF patterns saved."
    fi
}

phase_report() {
    log "===== Phase 8: Reporting ====="
    {
        echo "MaestroHunt Report for $DOMAIN"
        echo "=============================="
        echo "Run Date: $(date)"
        echo "Total Subdomains: $(wc -l < all_subs.txt 2>/dev/null || echo 0)"
        echo "Live Hosts: $(wc -l < live_hosts.txt 2>/dev/null || echo 0)"
        echo "Total URLs: $(wc -l < all_urls.txt 2>/dev/null || echo 0)"
        echo "Nuclei Findings: $(wc -l < nuclei_results.txt 2>/dev/null || echo 0)"
        echo "Potential XSS: $(wc -l < potential_xss.txt 2>/dev/null || echo 0)"
        echo "Potential SQLi: $(wc -l < potential_sqli.txt 2>/dev/null || echo 0)"
        echo "Potential LFI: $(wc -l < potential_lfi.txt 2>/dev/null || echo 0)"
        echo "Potential Open Redirect: $(wc -l < potential_open_redirect.txt 2>/dev/null || echo 0)"
    } > "report_summary.txt"
    cat report_summary.txt

    if [ -n "$NOTIFY_DISCORD_WEBHOOK" ] && command -v notify &>/dev/null; then
        echo "Recon for $DOMAIN complete. Findings: $(wc -l < nuclei_results.txt 2>/dev/null)" \
            | notify -silent -provider discord -webhook-url "$NOTIFY_DISCORD_WEBHOOK"
    fi
}

# ====================
# Main Execution
# ====================
main() {
    log "MaestroHunt started for $DOMAIN"
    log "Output directory: $TARGET_DIR"

    [ "${ENABLE_OSINT:-1}" -ne 0 ] && phase_osint
    [ "${ENABLE_PASSIVE:-1}" -ne 0 ] && phase_passive
    [ "${ENABLE_ACTIVE:-1}" -ne 0 ] && phase_active
    [ "${ENABLE_LIVE:-1}" -ne 0 ] && phase_live
    [ "${ENABLE_WEB:-1}" -ne 0 ] && phase_web
    [ "${ENABLE_PARAM:-1}" -ne 0 ] && phase_param
    [ "${ENABLE_VULN:-1}" -ne 0 ] && phase_vuln
    [ "${ENABLE_REPORT:-1}" -ne 0 ] && phase_report

    log "MaestroHunt completed successfully!"
}

main