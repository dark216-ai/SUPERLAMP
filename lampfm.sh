#!/usr/bin/env bash
#
# lampfm.sh — LAMP + FM Stack Installer & Service Manager
#
# Installs: apache2, mysql-server, php, phpmyadmin, python3, lftp, vsftpd, postfix, git
# Manages services: install, status, start, stop, restart, enable, disable
# Developer helpers: newsite, vhost add
#

set -euo pipefail
IFS=$'\n\t'

LOGFILE="/var/log/lampfm.log"
DATEFMT="+%Y-%m-%d %H:%M:%S"

# Colors
RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"; BLUE="\e[34m"; RESET="\e[0m"

# List of components and packages
declare -A COMPONENTS=(
  [apache2]="apache2"
  [mysql]="mysql-server"
  [php]="php libapache2-mod-php php-mysql php-cli"
  [phpmyadmin]="phpmyadmin"
  [python]="python3 python3-pip virtualenv"
  [ftp_client]="lftp"
  [ftp_server]="vsftpd"
  [mail]="postfix"
  [git]="git"
)

SERVICES=(apache2 mysql vsftpd postfix)

# Logging
log() {
  local lvl="$1"; shift
  local msg="$*"
  printf "%s [%s] %s\n" "$(date "$DATEFMT")" "$lvl" "$msg" \
    | tee -a "$LOGFILE"
}

info()  { log INFO "$*"; }
error() { log ERROR "$*"; echo -e "${RED}ERROR:${RESET} $*"; }

# Pre-checks
pre_checks() {
  [ "$EUID" -ne 0 ] && { error "Run as root"; exit 1; }
  ping -c1 8.8.8.8 &>/dev/null || { error "No network"; exit 1; }
}

# Install missing packages
install_all() {
  info "Installing missing components..."
  DEBIAN_FRONTEND=noninteractive apt-get update -qq
  for comp in "${!COMPONENTS[@]}"; do
    for pkg in ${COMPONENTS[$comp]}; do
      if ! dpkg -s "$pkg" &>/dev/null; then
        info "Installing $pkg"
        apt-get install -y -qq "$pkg"
      else
        info "$pkg already installed"
      fi
    done
  done
  info "Enabling apache2 mods"
  a2enmod rewrite &>/dev/null || true
  info "Reloading apache2"
  systemctl reload apache2
  echo -e "${GREEN}Installation complete.${RESET}"
}

# Show package status
status_packages() {
  echo "Package status:"
  for comp in "${!COMPONENTS[@]}"; do
    for pkg in ${COMPONENTS[$comp]}; do
      if dpkg -s "$pkg" &>/dev/null; then
        printf "  [${GREEN}OK${RESET}] %s\n" "$pkg"
      else
        printf "  [${RED}MISSING${RESET}] %s\n" "$pkg"
      fi
    done
  done
}

# Show service status
status_services() {
  echo "Service status:"
  for svc in "${SERVICES[@]}"; do
    if systemctl list-units --full -all | grep -q "^${svc}.service"; then
      local s=$(systemctl is-active "$svc")
      local e=$(systemctl is-enabled "$svc" 2>/dev/null || echo disabled)
      printf "  %s: %-8s (boot: %s)\n" "$svc" \
        "$( [[ $s == active ]] && echo "${GREEN}running${RESET}" || echo "${RED}stopped${RESET}" )" \
        "$e"
    else
      printf "  %s: ${YELLOW}not installed${RESET}\n" "$svc"
    fi
  done
}

# Control a service
svc_action() {
  local act="$1"; local svc="$2"
  if ! systemctl list-unit-files | grep -q "^${svc}.service"; then
    error "$svc not installed"
    return
  fi
  info "$act $svc"
  systemctl "$act" "$svc"
  echo -e "${GREEN}$svc ${act}ed${RESET}"
}

# Scaffold new site
newsite() {
  local name="$1"
  local dir="/var/www/html/$name"
  [ -d "$dir" ] && { error "Site $name exists"; return; }
  mkdir -p "$dir"
  cat >"$dir/index.php" <<EOF
<?php
phpinfo();
EOF
  cat >"$dir/index.py" <<EOF
#!/usr/bin/env python3
print("Content-type: text/plain\n")
print("Hello from $name")
EOF
  chmod +x "$dir/index.py"
  chown -R www-data:www-data "$dir"
  echo -e "${GREEN}Site $name created at $dir${RESET}"
}

# Add Apache virtual host
vhost_add() {
  local domain="$1"; local path="$2"
  local conf="/etc/apache2/sites-available/$domain.conf"
  [ -f "$conf" ] && { error "vhost $domain exists"; return; }
  cat >"$conf" <<EOF
<VirtualHost *:80>
    ServerName $domain
    DocumentRoot $path
    <Directory $path>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/$domain.error.log
    CustomLog \${APACHE_LOG_DIR}/$domain.access.log combined
</VirtualHost>
EOF
  a2ensite "$domain.conf"
  systemctl reload apache2
  echo -e "${GREEN}vhost $domain enabled${RESET}"
}

# Help
usage() {
  cat <<EOF
Usage: sudo $0 <command> [args]

Commands:
  install                 Install all missing components
  status packages         Show installed/missing packages
  status services         Show running/stopped services
  start <service>         Start a service
  stop <service>          Stop a service
  restart <service>       Restart a service
  enable <service>        Enable service at boot
  disable <service>       Disable service at boot
  newsite <name>          Scaffold /var/www/html/<name>
  vhost add <domain> <path>  Create & enable Apache vhost
  help                    Show this help
EOF
}

# Main
main() {
  pre_checks
  case "${1:-help}" in
    install)             install_all ;;
    status)
      case "${2:-}" in
        packages)  status_packages ;;
        services)  status_services ;;
        *)         usage ;;
      esac ;;
    start|stop|restart|enable|disable)
      svc_action "$1" "$2" ;;
    newsite)             newsite "$2" ;;
    vhost)
      [ "$2" = add ] && vhost_add "$3" "$4" || usage ;;
    help|--help|-h)      usage ;;
    *)                   usage ;;
  esac
}

main "$@"
