#!/usr/bin/env bash
set -euo pipefail

WT_HOME=/opt/ptc/Windchill
MARKER=/opt/ptc/.install_done
CONF_MARKER=/opt/ptc/.configured
HOOKS=/opt/ptc-scripts/hooks

log() { echo "[entrypoint] $(date '+%F %T') $*"; }

wait_tcp() {  # host port timeout
  local h=$1 p=$2 t=${3:-300} i=0
  until (echo > /dev/tcp/"$h"/"$p") 2>/dev/null; do
    i=$((i+2)); [ $i -ge "$t" ] && { log "Timeout en attendant $h:$p"; exit 1; }
    sleep 2
  done
  log "$h:$p disponible"
}

wait_tcp "$DB_HOST" "$DB_PORT" 300
wait_tcp "$LDAP_HOST" "$LDAP_PORT" 300

# --------------------------------------------------------------- 1. Installation
if [ ! -f "$MARKER" ]; then
  [ -d /opt/ptc-media ] && [ -n "$(ls -A /opt/ptc-media 2>/dev/null)" ] || {
    log "ERREUR : média PTC absent dans ./media (monté sur /opt/ptc-media)"; exit 1; }
  log "Installation silencieuse de Windchill : $PSI_INSTALL_CMD"
  bash -c "$PSI_INSTALL_CMD"
  while pgrep -f '[s]etup.bin LAX_VM' >/dev/null; do
    sleep 10
  done
  if [ ! -x "$WT_HOME/bin/windchill" ]; then
    log "ERREUR : PSI s'est terminé sans installer $WT_HOME/bin/windchill"
    exit 1
  fi
  touch "$MARKER"
fi

# --------------------------------------------------------------- 2. Configuration
if [ ! -f "$CONF_MARKER" ]; then
  log "Configuration de Windchill (xconfmanager)"
  XCONF="$WT_HOME/bin/xconfmanager"
  SITE="$WT_HOME/site.xconf"

  # !! Noms de propriétés à valider sur votre installation 13.1
  #    (cf. $WT_HOME/codebase/wt.properties.xconf et le guide PTC)
  "$XCONF" -s wt.rmi.server.hostname="$WC_HOSTNAME" -t "$SITE" -p || true
  "$XCONF" -s wt.server.codebase="http://${WC_HOSTNAME}:${WC_HTTP_PORT}/Windchill" -t "$SITE" -p || true
  "$XCONF" -s wt.pom.dbUser="$DB_USER" -t "$SITE" -p || true
  "$XCONF" -s wt.pom.dbPassword="$DB_PASSWORD" -t "$SITE" -p || true
  "$XCONF" -s wt.pom.serviceName="$DB_NAME" -t "$SITE" -p || true
  "$XCONF" -s wt.pom.jdbc.host="$DB_HOST" -t "$SITE" -p || true
  "$XCONF" -s wt.pom.jdbc.port="$DB_PORT" -t "$SITE" -p || true
  "$XCONF" -s wt.java.cmd.args.xmx="-Xmx${WC_XMX}" -t "$SITE" -p || true

  # Scripts utilisateur (création du schéma, chargement LDAP/initial load...)
  # Ils reçoivent DB_*, LDAP_* et WT_HOME dans l'environnement.
  export WT_HOME
  for f in "$HOOKS"/post-install-*.sh; do
    [ -e "$f" ] || continue
    log "Hook : $f"; bash "$f"
  done
  touch "$CONF_MARKER"
fi

# --------------------------------------------------------------- 3. Démarrage
log "Démarrage de Windchill"
"$WT_HOME/bin/windchill" start

stop() { log "Arrêt de Windchill"; "$WT_HOME/bin/windchill" stop || true; exit 0; }
trap stop SIGTERM SIGINT

LOGS="$WT_HOME/logs"
mkdir -p "$LOGS"
touch "$LOGS/MethodServer-.log" 2>/dev/null || true
tail -F "$LOGS"/*.log 2>/dev/null &
wait $!
