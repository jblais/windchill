#!/usr/bin/env bash
set -euo pipefail

WT_HOME=/opt/ptc/Windchill
MARKER=/opt/ptc/.install_done
CONF_MARKER=/opt/ptc/.configured
HOOKS=/opt/ptc-scripts/hooks

log() { echo "[entrypoint NONE] $(date '+%F %T') $*"; }

wait_tcp() {  # host port timeout
  local h=$1 p=$2 t=${3:-300} i=0
  until (echo > /dev/tcp/"$h"/"$p") 2>/dev/null; do
    i=$((i+2)); [ $i -ge "$t" ] && { log "Timeout en attendant $h:$p"; exit 1; }
    sleep 2
  done
  log "$h:$p disponible"
}

# Create sshd runtime directory
mkdir -p /run/sshd
chmod 755 /run/sshd

wait_tcp "$DB_HOST" "$DB_PORT" 300
wait_tcp "$LDAP_HOST" "$LDAP_PORT" 300

sleep infinity