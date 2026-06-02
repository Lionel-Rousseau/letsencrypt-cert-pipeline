#!/usr/bin/env bash
set -euo pipefail

HOSTS_FILE="${HOSTS_FILE:-/root/.secrets/cert-audit.hosts}"
WARN_DAYS="${WARN_DAYS:-30}"
CRIT_DAYS="${CRIT_DAYS:-14}"
TIMEOUT="${TIMEOUT:-10}"

if [[ -t 1 ]]; then
  RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'; RESET='\033[0m'
else
  RED=''; YELLOW=''; GREEN=''; RESET=''
fi

check_host() {
  local host="$1" port="${2:-443}" label="${3:-$1}"

  local end_date
  end_date="$(
    timeout "$TIMEOUT" openssl s_client \
      -connect "${host}:${port}" \
      -servername "$host" \
      </dev/null 2>/dev/null \
    | openssl x509 -noout -enddate 2>/dev/null \
    | cut -d= -f2 \
    || true
  )"

  if [[ -z "$end_date" ]]; then
    printf '%-42s %-6s %-12s %s\n' "$label" "$port" "-" "ERROR (unreachable or no cert)"
    worst=2
    return
  fi

  local end_ts now_ts days_left tag
  end_ts="$(date -d "$end_date" +%s)"
  now_ts="$(date +%s)"
  days_left="$(( (end_ts - now_ts) / 86400 ))"

  if (( days_left < 0 )); then
    tag="${RED}EXPIRED${RESET}"; [[ $worst -lt 2 ]] && worst=2
  elif (( days_left < CRIT_DAYS )); then
    tag="${RED}CRIT${RESET}";    [[ $worst -lt 2 ]] && worst=2
  elif (( days_left < WARN_DAYS )); then
    tag="${YELLOW}WARN${RESET}"; [[ $worst -lt 1 ]] && worst=1
  else
    tag="${GREEN}OK${RESET}"
  fi

  printf '%-42s %-6s %-12s ' "$label" "$port" "${days_left}d"
  printf "${tag}\n"
}

worst=0

printf '%-42s %-6s %-12s %s\n' "HOST" "PORT" "EXPIRES IN" "STATUS"
printf '%-42s %-6s %-12s %s\n' "────────────────────────────────────────" "────" "──────────" "──────"

if [[ "${1:-}" =~ ^(-h|--help|\?)$ ]]; then
  cat <<EOF
Usage: $(basename "$0") [host[:port[:label]] ...]

Without arguments, reads the inventory file (default: \$HOSTS_FILE).
With arguments, ignores the inventory file and audits only the given hosts.

Arguments:
  host[:port[:label]]   port defaults to 443, label defaults to host

Environment:
  HOSTS_FILE   path to inventory file  (default: /root/.secrets/cert-audit.hosts)
  WARN_DAYS    warning threshold in days (default: 30)
  CRIT_DAYS    critical threshold in days (default: 14)
  TIMEOUT      openssl connect timeout in seconds (default: 10)

Exit codes:
  0   all certificates OK
  1   at least one certificate expiring soon (< WARN_DAYS)
  2   at least one certificate expired, critical, or unreachable

Examples:
  $(basename "$0")
  $(basename "$0") remote.example.com:1234
  $(basename "$0") remote.example.com:1234:Freebox mail.example.com:443:Webmail
  WARN_DAYS=45 $(basename "$0")
EOF
  exit 0
fi

if [[ $# -gt 0 ]]; then
  # Arguments fournis : host[:port[:label]] ...
  for arg in "$@"; do
    IFS=: read -r host port label _rest <<< "$arg"
    check_host "$host" "${port:-443}" "${label:-$host}"
  done
else
  # Pas d'arguments : lecture du fichier d'inventaire
  if [[ ! -r "$HOSTS_FILE" ]]; then
    printf '[ERROR] Hosts file not readable: %s\n' "$HOSTS_FILE" >&2
    exit 1
  fi
  while IFS=: read -r host port label _rest; do
    [[ -z "${host:-}" || "${host:0:1}" == '#' ]] && continue
    check_host "$host" "${port:-443}" "${label:-$host}"
  done < "$HOSTS_FILE"
fi

printf '\n'

case $worst in
  0) printf "${GREEN}All certificates OK${RESET}\n" ;;
  1) printf "${YELLOW}WARNING: certificate(s) expiring soon${RESET}\n" ;;
  2) printf "${RED}CRITICAL: expired or unreachable certificate(s)${RESET}\n" ;;
esac

exit $worst
