#!/usr/bin/env bash
#
# lampfm.sh — LAMP + FM + Node.js Stack Installer & Service Manager
#
# Installs: apache2, mysql-server, php, phpmyadmin, python3, lftp, vsftpd,
#            postfix, git, build-essential, curl, nodejs
# Manages services: install, status, start, stop, restart, enable, disable
# Developer helpers: newsite, vhost add
#

set -euo pipefail
IFS=$'\n\t'

LOGFILE="/var/log/lampfm.log"
DATEFMT="+%Y-%m-%d %H:%M:%S"

# ─── Colors ───────────────────────────────────────────────────────────────
RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"; BLUE="\e[34m"; RESET="\e[0m"

# ─── Components & Packages ───────────────────────────────────────────────
declare -A COMPONENTS=(
  [apache2]="apache2"
  [database]="mysql-server"
  [php]="php libapache2-mod-php php-mysql php-cli"
  [phpmyadmin]="phpmyadmin"
  [python]="python3 python3-pip virtualenv"
  [ftp_client]="lftp"
  [ftp_server]="vsftpd"
  [mail]="postfix"
  [git]="git"
  [dev_tools]="build-essential curl"
  [nodejs]="nodejs"
)

SERVICES=(apache2 mysql vsftpd postfix)

# ─── Logging ─────────────────────────────────────────────────────────────
log() {
  local lvl="$1"; shift
  printf "%s [%s] %s\n" "$(date "$DATEFMT")" "$lvl" "$*" \
    | tee -a "$LOGFILE"
}
info()  { log INFO "$*"; }
error() { log ERROR "$*"; echo -e "${RED}ERROR:${RESET} $*"; }

# ─── Pre-checks ───────────────────────────────────────────────────────────
pre_checks() {
  [ "$EUID" -ne 0 ] && { error "Run as root"; exit 1; }
  ping -c1 8.8.8.8 &>/dev/null || { error "No network"; exit 1; }
}

# ─── System Update/Upgrade/Cleanup ────────────────────────────────────────
update_system() {
  info "Updating package index"
  apt-get update -qq
  info "Upgrading installed packages"
  DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq
  info "Performing dist-upgrade"
  DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y -qq
  info "Removing unused packages"
  apt-get autoremove -y -qq
  info "Cleaning package cache"
  apt-get autoclean -qq
}

# ─── External Repos ──────────────────────────────────────────────────────
add_node_repo() {
  info "Adding NodeSource repository for Node.js LTS"
  curl -fsSL https://deb.nodesource.com/setup_18.x | bash - &>>"$LOGFILE"
}

# ─── Install All Missing Components ──────────────────────────────────────
install_all() {
  update_system
  info "Installing missing components..."
  for comp in "${!COMPONENTS[@]}"; do
    [[ "$comp" == "nodejs" ]] && add_node_repo
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

# ─── Package Status ──────────────────────────────────────────────────────
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

# ─── Service Status ──────────────────────────────────────────────────────
status_services() {
  echo "Service status:"
  for svc in "${SERVICES[@]}"; do
    if systemctl list-unit-files | grep -q "^${svc}.service"; then
      local s=$(systemctl is-active "$svc")
      local e=$(systemctl is-enabled "$svc" 2>/dev/null || echo disabled)
      printf "  %s: %s (boot: %s)\n" \
        "$svc" \
        "$( [[ $s == active ]] && echo "${GREEN}running${RESET}" || echo "${RED}stopped${RESET}" )" \
        "$e"
    else
      printf "  %s: ${YELLOW}not installed${RESET}\n" "$svc"
    fi
  done
}

# ─── Service Control ─────────────────────────────────────────────────────
svc_action() {
  local act="$1"; local svc="$2"
  if ! systemctl list-unit-files | grep -q "^${svc}.service"; then
    error "Service '$svc' not found"
    return 1
  fi
  info "${act^}ing $svc"
  systemctl "$act" "$svc"
  echo -e "${GREEN}$svc ${act}ed${RESET}"
}

# ─── Scaffold New Site ───────────────────────────────────────────────────
newsite() {
  local name="$1"; local dir="/var/www/html/$name"
  [ -d "$dir" ] && { error "Site '$name' exists"; return 1; }
  mkdir -p "$dir"
  cat >"$dir/index.php" <<EOF
<?php
phpinfo();
EOF
  cat >"$dir/index.py" <<\PY
#!/usr/bin/env python3
print("Content-Type: text/plain\n")
print("Hello from $name")
PY
  chmod +x "$dir/index.py"
  chown -R www-data:www-data "$dir"
  echo -e "${GREEN}New site created at $dir${RESET}"
}

# ─── Add Apache Virtual Host ─────────────────────────────────────────────
vhost_add() {
  local domain="$1"; local path="$2"
  local conf="/etc/apache2/sites-available/$domain.conf"
  [ -f "$conf" ] && { error "vhost '$domain' already exists"; return 1; }
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

# ─── Usage/Help ──────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: sudo $0 <command> [args]

Commands:
  install                     Install/update all components
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

Examples:
  sudo $0 install
  sudo $0 status services
  sudo $0 start apache2
  sudo $0 newsite myproject
  sudo $0 vhost add myproject.local /var/www/html/myproject
EOF
}

# ─── Main ────────────────────────────────────────────────────────────────
main() {
  pre_checks
  case "${1:-help}" in
    install)            install_all ;;
    status)
      case "${2:-}" in
        packages)      status_packages ;;
        services)      status_services ;;
        *)             usage ;;
      esac ;;
    start|stop|restart|enable|disable)
                         svc_action "$1" "$2" ;;
    newsite)            newsite "$2" ;;
    vhost)
      [[ "$2" == "add" ]] && vhost_add "$3" "$4" || usage
      ;;
    help|--help|-h)     usage ;;
    *)                  usage ;;
  esac
}

main "$@"
