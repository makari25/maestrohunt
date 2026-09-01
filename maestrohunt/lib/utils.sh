#!/bin/bash
# lib/utils.sh – shared utilities for MaestroHunt

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "maestrohunt.log"
}

# Check if tool exists
check_tool() {
    if ! command -v "$1" &>/dev/null; then
        log "[!] $1 not found. Please install it."
        return 1
    fi
    return 0
}

# Create timestamped output directory
setup_output_dir() {
    local domain="$1"
    local base="${BASE_DIR:-$HOME/bugbounty}"
    local ts=$(date +%Y%m%d_%H%M%S)
    local dir="$base/$domain/$ts"
    mkdir -p "$dir"
    cd "$dir" || exit 1
    echo "$dir"
}