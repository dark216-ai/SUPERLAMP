#!/usr/bin/env bash
#
# superlamp.sh — The Ultimate LAMP + FM + DevOps Stack Installer & Manager
#
# Installs or manages: Apache2, MySQL/MariaDB, PHP, phpMyAdmin, Python3,
#  LFTP, vsftpd, Postfix, Git, build-essential, curl, Node.js LTS, Composer,
#  NVM, Docker, UFW, Fail2Ban, Certbot.
# Provides an ncurses menu, getopts flags, logging, dry‐run & verbose modes.
#

set -euo pipefail
IFS=$'\n\t'

SCRIPT_NAME=$(basename "$0")
LOGFILE="/var/log/superlamp.log"
DATEFMT="+%Y-%m-%d %H:%M:%S"

DRY_RUN=0
VERBOSE=0

# ─── Colors ─────────────────────────────────────────────────────────────────
RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"; BLUE="\e[34m"; RESET="\e[0m"

# ─── Ensure log file & rotate if >5MB ─────────────────────────────────────
init_log() {
  mkdir -p "$(dirname "$LOGFILE")"
  if [ -f "$LOGFILE" ] && [ "$(stat -c%s "$LOGFILE")" -gt $((5*1024*1024)) ]; then
    mv "$LOGFILE" "$LOGFILE.$(date +%s)"
  fi
  : >"$LOGFILE"
}

# ─── Logging Helpers ───────────────────────────────────────────────────────
log() {
  local level="$1"; shift
  printf "%s [%5s] %s\n" "$(date "$DATEFMT")" "$level" "$*" \
    | tee -a "$LOGFILE"
}
info()  { log INFO  "$*"; [[ $VERBOSE -eq 1 ]] && echo -e "${BLUE}$*${RESET}"; }
warn()  { log WARN  "$*"; echo -e "${YELLOW}WARN: $*${RESET}"; }
error() { log ERROR "$*"; echo -e "${RED}ERROR: $*${RESET}"; }

# ─── Dry‐Run Wrapper ────────────────────────────────────────────────────────
run() {
  local cmd="$*"
  if [ $DRY_RUN -eq 1 ]; then
    echo "[DRY-RUN] $cmd"
  else
    eval "$cmd"
  fi
}

# ─── Pre‐checks ────────────────────────────────────────────────────────────
pre_checks() {
  init_log
  [ "$EUID" -ne 0 ] && error "Run as root" && exit 1
  ping -c1 1.1.1.1 &>/dev/null || error "No network" && exit 1
  command -v whiptail &>/dev/null || run "apt-get update -qq && apt-get install -y -qq whiptail"
}

# ─── System Maintenance ────────────────────────────────────────────────────
update_system() {
  info "Updating package index"
  run "apt-get update -qq"
  info "Upgrading installed packages"
  run "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq"
  info "Performing dist-upgrade"
  run "DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y -qq"
  info "Autoremoving unused packages"
  run "apt-get autoremove -y -qq"
  info "Cleaning package cache"
  run "apt-get autoclean -qq"
}

# ─── Add External Repos ─────────────────────────────────────────────────────
add_node_repo() {
  info "Adding NodeSource LTS repo"
  run "curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -"
}

# ─── Components & Services ─────────────────────────────────────────────────
COMPONENTS=(
  "Apache2|apache2"
  "Database|mysql-server"
  "PHP|php libapache2-mod-php php-mysql php-cli"
  "phpMyAdmin|phpmyadmin"
  "Python3|python3 python3-pip virtualenv"
  "FTP Client|lftp"
  "FTP Server|vsftpd"
  "Mail Server|postfix"
  "Git|git"
  "Dev Tools|build-essential curl"
  "Node.js|nodejs"
  "Composer|composer"
  "NVM|nvm"
  "Docker|docker.io docker-compose"
  "Firewall|ufw"
  "Fail2Ban|fail2ban"
  "SSL & Certbot|certbot python3-certbot-apache"
)
declare -A SERVICE_MAP=(
  [apache2]="apache2"
  [mysql-server]="mysql"
  [vsftpd]="vsftpd"
  [postfix]="postfix"
  [docker.io]="docker"
  [ufw]="ufw"
  [fail2ban]="fail2ban"
)

# ─── TUI: Install Components ────────────────────────────────────────────────
install_components() {
  local choices=()
  for item in "${COMPONENTS[@]}"; do
    local name="${item%%|*}"
    choices+=( "$name" "$name" off )
  done
  local sel=$(whiptail --separate-output --title "Select Components" \
    --checklist "Use SPACE to select, ENTER to confirm" 20 60 16 \
    "${choices[@]}" 3>&1 1>&2 2>&3) || return

  update_system
  for name in $sel; do
    for item in "${COMPONENTS[@]}"; do
      [[ "${item%%|*}" == "$name" ]] || continue
      local pkgs="${item#*|}"
      info "Installing $name"
      [[ "$name" == "Node.js" ]] && add_node_repo
      for pkg in $pkgs; do
        if dpkg -s "$pkg" &>/dev/null; then
          info "  $pkg already installed"
        else
          run "apt-get install -y -qq $pkg"
        fi
      done
      break
    done
  done

  info "Enabling Apache rewrite"
  run "a2enmod rewrite"
  run "systemctl reload apache2"
  whiptail --msgbox "Installation complete!" 8 40
}

# ─── TUI: Manage Services ───────────────────────────────────────────────────
manage_services() {
  local choices=()
  for pkg in "${!SERVICE_MAP[@]}"; do
    local svc=${SERVICE_MAP[$pkg]}
    dpkg -s "$pkg" &>/dev/null || continue
    local state=$(systemctl is-active "$svc")
    choices+=( "$svc" "$svc [$state]" off )
  done
  local sel=$(whiptail --separate-output --title "Service Manager" \
    --checklist "Select services" 20 60 12 "${choices[@]}" 3>&1 1>&2 2>&3) || return

  local act=$(whiptail --title "Choose Action" --menu "Action" 10 40 4 \
    start "Start" stop "Stop" restart "Restart" 3>&1 1>&2 2>&3) || return

  for svc in $sel; do
    info "$act $svc"
    run "systemctl $act $svc"
  done
  whiptail --msgbox "Services updated." 8 40
}

# ─── TUI: Database Wizard ──────────────────────────────────────────────────
db_wizard() {
  local user=$(whiptail --inputbox "DB username:" 8 40 3>&1 1>&2 2>&3) || return
  local pass=$(whiptail --passwordbox "DB password:" 8 40 3>&1 1>&2 2>&3) || return
  local db  =$(whiptail --inputbox "DB name:" 8 40 3>&1 1>&2 2>&3) || return
  info "Creating database/user"
  run "mysql -e \"CREATE DATABASE \\\`$db\\\`; \
    CREATE USER '$user'@'localhost' IDENTIFIED BY '$pass'; \
    GRANT ALL ON \\\`$db\\\`.* TO '$user'@'localhost'; FLUSH PRIVILEGES;\""
  whiptail --msgbox "Database '$db' and user '$user' created." 8 50
}

# ─── TUI: SSL Setup via Certbot ────────────────────────────────────────────
setup_ssl() {
  local domain=$(whiptail --inputbox "Domain for SSL (e.g. example.com):" 8 60 3>&1 1>&2 2>&3) || return
  info "Issuing certificate for $domain"
  run "certbot --apache -d $domain --non-interactive --agree-tos -m admin@$domain"
  whiptail --msgbox "SSL enabled for $domain." 8 50
}

# ─── TUI: Firewall & Fail2Ban ──────────────────────────────────────────────
configure_firewall() {
  info "Configuring UFW"
  run "ufw allow OpenSSH"
  run "ufw allow 'WWW Full'"
  run "ufw allow ftp"
  run "ufw --force enable"
}
configure_fail2ban() {
  info "Enabling Fail2Ban"
  run "systemctl enable fail2ban"
  run "systemctl start fail2ban"
  whiptail --msgbox "Firewall & Fail2Ban configured." 8 40
}

# ─── TUI: Composer & NVM ───────────────────────────────────────────────────
install_composer() {
  info "Installing Composer"
  run "curl -sS https://getcomposer.org/installer | php"
  run "mv composer.phar /usr/local/bin/composer"
}
install_nvm() {
  info "Installing NVM"
  run "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash"
  whiptail --msgbox "NVM installed. Restart shell to use." 8 50
}

# ─── TUI: Docker ──────────────────────────────────────────────────────────
install_docker() {
  info "Installing Docker & Compose"
  run "apt-get install -y -qq docker.io docker-compose"
  run "systemctl enable docker"
  run "systemctl start docker"
  whiptail --msgbox "Docker installed and running." 8 50
}

# ─── Main Menu ────────────────────────────────────────────────────────────
main_menu() {
  while true; do
    local choice=$(whiptail --clear --title "SUPERLAMP Main Menu" \
      --menu "Select an option:" 18 60 10 \
      1 "Install Components" \
      2 "Manage Services" \
      3 "Database Wizard" \
      4 "SSL Setup (Certbot)" \
      5 "Firewall & Fail2Ban" \
      6 "Install Composer & NVM" \
      7 "Install Docker" \
      8 "Exit" 3>&1 1>&2 2>&3) || exit
    case "$choice" in
      1) install_components ;;
      2) manage_services ;;
      3) db_wizard ;;
      4) setup_ssl ;;
      5) configure_firewall; configure_fail2ban ;;
      6) install_composer; install_nvm ;;
      7) install_docker ;;
      8) break ;;
    esac
  done
}

# ─── Option Parsing ────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: sudo $SCRIPT_NAME [options]

Options:
  -n, --dry-run     Show commands without executing
  -v, --verbose     Show verbose output
  -h, --help        Display this help and exit
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)  DRY_RUN=1; shift ;;
    -v|--verbose)  VERBOSE=1; shift ;;
    -h|--help)     usage; exit 0 ;;
    *)             echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

pre_checks
main_menu
echo -e "${GREEN}Goodbye!${RESET}"
