#!/usr/bin/env bash
#
# lampfm.sh — LAMP + FM + Node.js + Dev Tools Installer & TUI Manager
# Implements: getopts, auto service mapping, whiptail TUI, DB wizard,
# SSL automation, firewall (ufw & fail2ban), Composer, NVM, Docker.
#

set -euo pipefail
IFS=$'\n\t'

LOGFILE="/var/log/lampfm.log"
DATEFMT="+%Y-%m-%d %H:%M:%S"
DRY_RUN=0
VERBOSE=0

# Colors
RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"; BLUE="\e[34m"; RESET="\e[0m"

# Components: name|apt-packages
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
  "SSL (Certbot)|certbot python3-certbot-apache"
)

# Automatically discovered services from installed components
declare -A SERVICE_MAP=(
  [apache2]="apache2"
  [mysql-server]="mysql"
  [vsftpd]="vsftpd"
  [postfix]="postfix"
  [docker.io]="docker"
  [fail2ban]="fail2ban"
  [ufw]="ufw"
)

# Logging
log() {
  local lvl="$1"; shift
  printf "%s [%s] %s\n" "$(date "$DATEFMT")" "$lvl" "$*" \
    | tee -a "$LOGFILE"
}
info()  { log INFO "$*"; ((VERBOSE)) && echo -e "${BLUE}$*${RESET}"; }
error() { log ERROR "$*"; echo -e "${RED}ERROR: $*${RESET}"; }

# Pre‐checks
pre_checks() {
  [ "$EUID" -ne 0 ] && { error "Run as root"; exit 1; }
  ping -c1 1.1.1.1 &>/dev/null || { error "No network"; exit 1; }
  command -v whiptail &>/dev/null || apt-get update -qq && apt-get install -y -qq whiptail
}

# System update & upgrade
update_system() {
  info "Updating package index..."
  $dry_apt_update
  info "Upgrading packages..."
  $dry_apt_upgrade
}

# Dry-run wrappers
dry_apt_update="apt-get update -qq"
dry_apt_upgrade="DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq"
dry_install="apt-get install -y -qq"
run_or_dry() {
  if (( DRY_RUN )); then
    echo "[DRY-RUN] $*"
  else
    eval "$*"
  fi
}

# Add NodeSource repo for Node.js LTS
add_node_repo() {
  info "Adding Node.js LTS repo"
  run_or_dry "curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -"
}

# Install selected components
install_components() {
  local sel pkgs comp
  sel=$(whiptail --title "LAMPFM Installer" --checklist \
    "Select components to install" 20 80 14 \
    $(for c in "${COMPONENTS[@]}"; do
        name="${c%%|*}"; pkgs="${c#*|}"
        echo "\"$name\" \"${pkgs%% *}\" off"
     done) 3>&1 1>&2 2>&3) || return
  update_system
  for comp in $sel; do
    for entry in "${COMPONENTS[@]}"; do
      name="${entry%%|*}"; pkgs="${entry#*|}"
      if [[ "$name" == "$comp" ]]; then
        info "Installing $name"
        [[ "$name" == "Node.js" ]] && add_node_repo
        for pkg in $pkgs; do
          if dpkg -s "$pkg" &>/dev/null; then
            info "$pkg already installed"
          else
            run_or_dry "$dry_install $pkg"
          fi
        done
        break
      fi
    done
  done
  info "Enabling Apache mod_rewrite"
  run_or_dry "a2enmod rewrite"
  run_or_dry "systemctl reload apache2"
}

# Virtual host SSL automation
setup_ssl() {
  local domain
  domain=$(whiptail --inputbox "Enter your domain for SSL (example.com)" 8 60 3>&1 1>&2 2>&3) || return
  info "Obtaining SSL cert for $domain"
  run_or_dry "certbot --apache -d $domain --non-interactive --agree-tos -m admin@$domain"
}

# Firewall & Fail2Ban
configure_firewall() {
  info "Configuring UFW"
  run_or_dry "ufw allow OpenSSH"
  run_or_dry "ufw allow 'WWW Full'"
  run_or_dry "ufw allow ftp"
  run_or_dry "ufw enable"
}
configure_fail2ban() {
  info "Enabling Fail2Ban"
  run_or_dry "systemctl enable fail2ban"
  run_or_dry "systemctl start fail2ban"
}

# Database wizard
db_wizard() {
  local user pass db
  user=$(whiptail --inputbox "New DB username" 8 40 3>&1 1>&2 2>&3) || return
  pass=$(whiptail --passwordbox "Password for $user" 8 40 3>&1 1>&2 2>&3) || return
  db=$(whiptail --inputbox "Database name" 8 40 3>&1 1>&2 2>&3) || return
  info "Creating database & user"
  run_or_dry "mysql -e \"CREATE DATABASE \\\`$db\\\`; GRANT ALL ON \\\`$db\\\`.* TO '$user'@'localhost' IDENTIFIED BY '$pass'; FLUSH PRIVILEGES;\""
}

# Composer & NVM
install_composer() {
  info "Installing Composer"
  run_or_dry "curl -sS https://getcomposer.org/installer | php"
  run_or_dry "mv composer.phar /usr/local/bin/composer"
}
install_nvm() {
  info "Installing NVM"
  run_or_dry "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash"
}

# Docker support
install_docker() {
  info "Installing Docker & Compose"
  run_or_dry "apt-get install -y -qq docker.io docker-compose"
  run_or_dry "systemctl enable docker"
  run_or_dry "systemctl start docker"
}

# Manage services using dialog
manage_services() {
  local choices sel svc act
  # auto-discover services
  choices=$(for s in "${!SERVICE_MAP[@]}"; do
    pkg="$s"; svc="${SERVICE_MAP[$s]}"
    if dpkg -s "$pkg" &>/dev/null; then
      state=$(systemctl is-active "$svc")
      echo "\"$svc\" \"$svc ($state)\" off"
    fi
  done)
  sel=$(whiptail --title "Service Manager" --checklist \
    "Select services to start/stop/restart" 20 70 10 $choices 3>&1 1>&2 2>&3) || return
  act=$(whiptail --title "Action" --menu \
    "Choose action for selected" 12 40 4 \
    "start" "Start services" \
    "stop" "Stop services" \
    "restart" "Restart services" 3>&1 1>&2 2>&3) || return
  for svc in $sel; do
    info "$act $svc"
    run_or_dry "systemctl $act $svc"
  done
}

# Main menu
main_menu() {
  while true; do
    choice=$(whiptail --title "LAMPFM Main Menu" --menu "Choose an option" 16 60 8 \
      "1" "Install Components" \
      "2" "Manage Services" \
      "3" "DB Setup Wizard" \
      "4" "SSL Setup (Certbot)" \
      "5" "Configure Firewall & Fail2Ban" \
      "6" "Install Composer & NVM" \
      "7" "Install Docker" \
      "8" "Exit" 3>&1 1>&2 2>&3) || exit
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

# Parse options
while getopts ":hnv-:" opt; do
  case "$opt" in
    h) echo "Usage: $0 [-n dry-run] [-v verbose]"; exit 0 ;;
    n) DRY_RUN=1 ;;
    v) VERBOSE=1 ;;
    -)
      case "${OPTARG}" in
        dry-run) DRY_RUN=1 ;;
        verbose) VERBOSE=1 ;;
        help)    echo "Usage: $0 [--dry-run] [--verbose]"; exit 0 ;;
      esac ;;
    \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
  esac
done

pre_checks
main_menu
echo -e "${GREEN}Goodbye!${RESET}"
