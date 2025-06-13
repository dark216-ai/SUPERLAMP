#!/usr/bin/env bash
#
# lampfm.sh — LAMP + FM + Node.js Stack Installer & Service Manager
#
# Installs or manages: Apache2, MySQL/MariaDB, PHP, phpMyAdmin, Python3, LFTP, vsftpd,
# Postfix, Git, build-essential, curl, Node.js LTS.
# Provides commands: install, status packages/services, start/stop/restart/enable/disable,
# newsite, vhost add.
#

set -euo pipefail
IFS=$'\n\t'

LOGFILE="/var/log/lampfm.log"
DATEFMT="+%Y-%m-%d %H:%M:%S"

# Colors
RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"; BLUE="\e[34m"; RESET="\e[0m"

# Ensure log file exists
mkdir -p "$(dirname "$LOGFILE")"
: >"$LOGFILE"

# Components in order
COMP_ORDER=(dev_tools apache2 database php phpmyadmin python ftp_client ftp_server mail git nodejs)
declare -A COMPONENTS=(
  [dev_tools]="build-essential curl"
  [apache2]="apache2"
  [database]="mysql-server"
  [php]="php libapache2-mod-php php-mysql php-cli"
  [phpmyadmin]="phpmyadmin"
  [python]="python3 python3-pip virtualenv"
  [ftp_client]="lftp"
  [ftp_server]="vsftpd"
  [mail]="postfix"
  [git]="git"
  [nodejs]="nodejs"
)

SERVICES=(apache2 mysql vsftpd postfix)

# Logging
log() {
  local level="$1"; shift
  printf "%s [%s] %s\n" "$(date "$DATEFMT")" "$level" "$*" \
    | tee -a "$LOGFILE"
}
info()  { log INFO "$*"; }
error() { log ERROR "$*"; echo -e "${RED}ERROR:${RESET} $*"; }

# Pre-checks
pre_checks() {
  [ "$EUID" -ne 0 ] && { error "This script must be run as root"; exit 1; }
  ping -c1 1.1.1.1 &>/dev/null || { error "No network connection"; exit 1; }
}

# System maintenance
update_system() {
  info "Updating package index"
  apt-get update -qq
  info "Upgrading installed packages"
  DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq
  info "Dist-upgrade"
  DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y -qq
  info "Autoremove unused packages"
  apt-get autoremove -y -qq
  info "Autoclean cache"
  apt-get autoclean -qq
}

# Add NodeSource repo
add_node_repo() {
  if ! grep -q "nodesource" /etc/apt/sources.list.d/nodesource.list 2>/dev/null; then
    info "Adding NodeSource repository"
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - &>>"$LOGFILE"
  fi
}

# Install all missing components
install_all() {
  update_system
  info "Installing missing components"
  for comp in "${COMP_ORDER[@]}"; do
    [ "$comp" = nodejs ] && add_node_repo
    for pkg in ${COMPONENTS[$comp]}; do
      if ! dpkg -s "$pkg" &>/dev/null; then
        info "Installing $pkg"
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$pkg"
      else
        info "$pkg already installed"
      fi
    done
  done
  info "Enabling Apache rewrite module"
  a2enmod rewrite &>/dev/null || true
  info "Reloading Apache"
  systemctl reload apache2
  echo -e "${GREEN}All components installed and configured.${RESET}"
}

# Show package status
status_packages() {
  echo "Package status:"
  for comp in "${COMP_ORDER[@]}"; do
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
    if systemctl list-unit-files | grep -q "^${svc}.service"; then
      local state=$(systemctl is-active "$svc")
      local enable=$(systemctl is-enabled "$svc" 2>/dev/null || echo disabled)
      printf "  %s: %-8s (boot: %s)\n" \
        "$svc" \
        "$( [[ $state == active ]] && echo "${GREEN}running${RESET}" || echo "${RED}stopped${RESET}" )" \
        "$enable"
    else
      printf "  %s: ${YELLOW}not installed${RESET}\n" "$svc"
    fi
  done
}

# Service control
svc_action() {
  local act="$1" svc="$2"
  if ! systemctl list-unit-files | grep -q "^${svc}.service"; then
    error "Service '$svc' not found"; return 1
  fi
  info "${act^}ing $svc"; systemctl "$act" "$svc"
  echo -e "${GREEN}$svc ${act}ed${RESET}"
}

# Scaffold new site
newsite() {
  local name="$1"
  local dir="/var/www/html/$name"
  [ -d "$dir" ] && { error "Site '$name' already exists"; return 1; }
  mkdir -p "$dir"
  cat >"$dir/index.php" <<EOF
<?php
phpinfo();
EOF
  cat >"$dir/index.py" <<EOF
#!/usr/bin/env python3
print("Content-Type: text/plain\n")
print("Hello from $name")
EOF
  chmod +x "$dir/index.py"
  chown -R www-data:www-data "$dir"
  echo -e "${GREEN}Site '$name' created at $dir${RESET}"
}

# Add Apache virtual host
vhost_add() {
  local domain="$1" path="$2"
  local conf="/etc/apache2/sites-available/$domain.conf"
  [ -f "$conf" ] && { error "vhost '$domain' exists"; return 1; }
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
  echo -e "${GREEN}vhost '$domain' enabled${RESET}"
}

# Usage
usage() {
  cat <<EOF
Usage: sudo $0 <command> [args]

Commands:
  install                     Install all missing components
  status packages             Show installed/missing packages
  status services             Show running/stopped services
  start <service>             Start a service (apache2, mysql, vsftpd, postfix)
  stop <service>              Stop a service
  restart <service>           Restart a service
  enable <service>            Enable service at boot
  disable <service>           Disable service at boot
  newsite <name>              Scaffold /var/www/html/<name>
  vhost add <domain> <path>   Create & enable Apache vhost
  help                        Show this help message
EOF
}

# Main
main() {
  pre_checks
  case "${1:-help}" in
    install)                install_all ;;
    status)
      case "${2:-}" in
        packages)           status_packages ;;
        services)           status_services ;;
        *)                  usage ;;
      esac ;;
    start|stop|restart|enable|disable)
                            svc_action "$1" "$2" ;;
    newsite)                newsite "$2" ;;
    vhost)
      [ "${2:-}" = add ] && vhost_add "$3" "$4" || usage ;;
    help|--help|-h)         usage ;;
    *)                      usage ;;
  esac
}

main "$@"
