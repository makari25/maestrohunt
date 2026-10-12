
#!/usr/bin/env bash
# MaestroHunt - Automated Bug Bounty Recon Pipeline

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.conf"
TARGET=""

usage() {
    cat <<'EOF'
MaestroHunt - Authorized reconnaissance

Usage:
  ./maestrohunt.sh <domain> [--config <file>]
  ./maestrohunt.sh --help

Options:
  --config FILE   Use a specific configuration file
  --help          Display this help message
EOF
}

while (($#)); do
    case "$1" in
        --config)
            if (($# < 2)) || [[ -z "$2" || "$2" == --* ]]; then
                echo "[ERROR] --config requires a file path." >&2
                exit 2
            fi
            CONFIG_FILE="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        -*)
            echo "[ERROR] Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
        *)
            if [[ -n "$TARGET" ]]; then
                echo "[ERROR] Only one target domain is supported." >&2
                exit 2
            fi
            TARGET="$1"
            shift
            ;;
    esac
done

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "[ERROR] Config not found: $CONFIG_FILE" >&2
    echo "Copy config.conf.example to config.conf first." >&2
    exit 1
fi

# Load trusted, locally maintained shell configuration.
# Never source a configuration downloaded from an untrusted source.
# shellcheck source=/dev/null
source "$CONFIG_FILE"

DOMAIN="${TARGET:-${DOMAIN:-}}"

if [[ -z "$DOMAIN" ]]; then
    echo "[ERROR] A target domain is required." >&2
    usage >&2
    exit 2
fi

DOMAIN="${DOMAIN%.}"

if ((${#DOMAIN} > 253)) ||
   [[ "$DOMAIN" != *.* || "$DOMAIN" == *..* ]] ||
   [[ ! "$DOMAIN" =~ ^[A-Za-z0-9.-]+$ ]]; then
    echo "[ERROR] Invalid domain format: $DOMAIN" >&2
    exit 2
fi

if [[ "$DOMAIN" == .* || "$DOMAIN" == *-.* ||
      "$DOMAIN" == *.-* || "$DOMAIN" == *.-* ]]; then
    echo "[ERROR] Invalid domain label: $DOMAIN" >&2
    exit 2
fi

printf '[INFO] Configuration: %s\n' "$CONFIG_FILE"
printf '[INFO] Requested target: %s\n' "$DOMAIN"
printf '[INFO] Ensure this target is explicitly authorized before scanning.\n'
