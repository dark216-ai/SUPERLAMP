#!/usr/bin/env bash
#
# superlamp.sh — The Ultimate LAMP + FM + DevOps Stack Installer & Manager
#
# Installs/manages: Apache2, MySQL/MariaDB, PHP(+phpMyAdmin),
#  Python3, Git, LFTP/vsftpd, Postfix, Node.js LTS, Composer, NVM,
#  Docker & Compose, UFW, Fail2Ban, Certbot.
# Provides ncurses TUI, smart update/upgrade, retries, dry‐run & verbose modes.
#

set -euo pipefail
IFS=$'\n\t'

# ─── Globals & Config ──────────────────────────────────────────────────────
SCRIPT_NAME=$(basename "$0")
LOGFILE="/var/log/superlamp.log"
DATEFMT="+%Y-%m-%d %H:%M:%S"
DRY_RUN=0
VERBOSE=0

# APT settings
APT_TTL=$((6*3600))      # skip update if run within last 6h
MAX_RETRIES=3            # apt retry count
RETRY_DELAY=5            # seconds between retries
USE_APT_FAST=1           # prefer apt-fast if installed
ENABLE_UNATTENDED=1      # install unattended-upgrades
CLEANUP_OLD_KERNELS=1    # remove old kernels

# ─── Colors ────────────────────────────────────────────────────────────────
RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"; BLUE="\e[34m"; RESET="\e[0m"

# ─── Init & Logging ────────────────────────────────────────────────────────
init_log() {
  mkdir -p "$(dirname "$LOGFILE")"
  if [ -f "$LOGFILE" ] && [ "$(stat -c%s "$LOGFILE")" -gt $((5*1024*1024)) ]; then
    mv "$LOGFILE" "$LOGFILE.$(date +%s)"
  fi
  : >"$LOGFILE"
}
log()   { printf "%s [%5s] %s\n" "$(date "$DATEFMT")" "$1" "${@:2}" \
            | tee -a "$LOGFILE"; }
info()  { log INFO "$*"; [[ $VERBOSE -eq 1 ]] && echo -e "${BLUE}$*${RESET}"; }
warn()  { log WARN "$*"; echo -e "${YELLOW}WARN: $*${RESET}"; }
error() { log ERROR "$*"; echo -e "${RED}ERROR: $*${RESET}"; }

# ─── Dry‐run Wrapper ────────────────────────────────────────────────────────
run() {
  if [ $DRY_RUN -eq 1 ]; then
    echo "[DRY-RUN] $*"
  else
    eval "$*"
  fi
}

# ─── Pre‐checks ────────────────────────────────────────────────────────────
pre_checks() {
  init_log
  [ "$EUID" -ne 0 ] && error "Must be run as root" && exit 1
  ping -c1 1.1.1.1 &>/dev/null || error "No network" && exit 1
  command -v whiptail &>/dev/null || run "apt-get update -qq && apt-get install -y -qq whiptail"
}

# ─── APT Helpers: retry/backoff & smart commands ────────────────────────────
apt_retry() {
  local cmd="$*"; local n=0
  until [ $n -ge $MAX_RETRIES ]; do
    if eval "$cmd"; then return 0; fi
    n=$((n+1))
    warn "APT failed, retrying in ${RETRY_DELAY}s ($n/$MAX_RETRIES)..."
    sleep $RETRY_DELAY
  done
  error "APT failed after $MAX_RETRIES attempts: $cmd"; return 1
}
apt_cmd() {
  if [ $USE_APT_FAST -eq 1 ] && command -v apt-fast &>/dev/null; then
    echo "apt-fast"
  else
    echo "apt-get"
  fi
}
last_stamp="/var/lib/apt/periodic/update-success-stamp"
smart_update() {
  local now=$(date +%s)
  if [ -f "$last_stamp" ]; then
    local last=$(stat -c %Y "$last_stamp")
    (( now - last < APT_TTL )) && info "Skipping apt update (recent)" && return
  fi
  info "Running apt update"
  apt_retry "$(apt_cmd) update -qq"
}
smart_upgrade() {
  info "Running apt upgrade"
  apt_retry "DEBIAN_FRONTEND=noninteractive $(apt_cmd) upgrade -y -qq"
}
smart_full_upgrade() {
  info "Running apt full-upgrade"
  apt_retry "DEBIAN_FRONTEND=noninteractive $(apt_cmd) full-upgrade -y -qq"
}
smart_cleanup() {
  info "Autoremoving unused packages"
  apt_retry "apt-get autoremove -y -qq"
  info "Cleaning package cache"
  apt_retry "apt-get autoclean -qq"
}
enable_unattended() {
  if [ $ENABLE_UNATTENDED -eq 1 ]; then
    info "Installing unattended-upgrades"
    apt_retry "$(apt_cmd) install -y -qq unattended-upgrades"
    info "Configuring unattended-upgrades"
    run "dpkg-reconfigure -fnoninteractive unattended-upgrades"
  fi
}
cleanup_old_kernels() {
  if [ $CLEANUP_OLD_KERNELS -eq 1 ]; then
    info "Removing old kernels"
    dpkg --list 'linux-image-[0-9]*' \
      | awk '/^ii/{print $2}' \
      | grep -Ev "$(uname -r | sed 's/\(.*\)-.*/\1/')|generic" \
      | xargs -r apt-get purge -y -qq
  fi
}

# ─── System Maintenance ────────────────────────────────────────────────────
system_maintenance() {
  smart_update
  smart_upgrade
  smart_full_upgrade
  enable_unattended
  cleanup_old_kernels
  smart_cleanup
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
    --checklist "Use SPACE to select" 20 60 16 \
    "${choices[@]}" 3>&1 1>&2 2>&3) || return

  system_maintenance
  for name in $sel; do
    for item in "${COMPONENTS[@]}"; do
      [[ "${item%%|*}" == "$name" ]] || continue
      local pkgs="${item#*|}"
      info "Installing $name"
      [[ "$name" == "Node.js" ]] && run "curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -"
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

  info "Enabling Apache mod_rewrite"
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
  local user=$(whiptail --inputbox "DB username:"   8 40 3>&1) || return
  local pass=$(whiptail --passwordbox "Password:"  8 40 3>&1) || return
  local db =$(whiptail --inputbox "DB name:"       8 40 3>&1) || return
  info "Creating database & user"
  run "mysql -e \"CREATE DATABASE \\\`$db\\\`; \
    CREATE USER '$user'@'localhost' IDENTIFIED BY '$pass'; \
    GRANT ALL ON \\\`$db\\\`.* TO '$user'@'localhost'; FLUSH PRIVILEGES;\""
  whiptail --msgbox "Database '$db' created." 8 50
}

# ─── TUI: SSL Setup via Certbot ────────────────────────────────────────────
setup_ssl() {
  local domain=$(whiptail --inputbox "Domain (e.g. example.com):" 8 60 3>&1) || return
  info "Issuing SSL for $domain"
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

# ─── TUI: Docker & Compose ─────────────────────────────────────────────────
install_docker() {
  info "Installing Docker & Compose"
  run "apt-get install -y -qq docker.io docker-compose"
  run "systemctl enable docker"
  run "systemctl start docker"
  whiptail --msgbox "Docker installed and running." 8 50
}

# ─── TUI: Scaffold New Site ────────────────────────────────────────────────
newsite() {
  local name=$(whiptail --inputbox "New site name:" 8 40 3>&1) || return
  local dir="/var/www/html/$name"
  [ -d "$dir" ] && { error "Site '$name' exists"; return; }
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
  whiptail --msgbox "Site '$name' created at $dir." 8 50
}

# ─── TUI: Add Apache vhost ─────────────────────────────────────────────────
vhost_add() {
  local domain=$(whiptail --inputbox "Vhost domain:" 8 40 3>&1) || return
  local path=$(whiptail --inputbox "Document root:" 8 60 "/var/www/html/$domain" 3>&1) || return
  local conf="/etc/apache2/sites-available/$domain.conf"
  [ -f "$conf" ] && { error "vhost '$domain' exists"; return; }
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
  run "a2ensite $domain.conf"
  run "systemctl reload apache2"
  whiptail --msgbox "vhost '$domain' enabled." 8 50
}

# ─── Main Menu ──────────────────────────────────────────────────────────────
main_menu() {
  while true; do
    local choice=$(whiptail --clear --title "SUPERLAMP Main Menu" \
      --menu "Select an option:" 20 60 10 \
      1 "Install Components" \
      2 "Manage Services" \
      3 "Database Wizard" \
      4 "SSL Setup" \
      5 "Firewall & Fail2Ban" \
      6 "Install Composer & NVM" \
      7 "Install Docker" \
      8 "New Site Scaffold" \
      9 "Add Apache vhost" \
      10 "Exit" 3>&1 1>&2 2>&3) || exit
    case "$choice" in
      1) install_components ;;
      2) manage_services ;;
      3) db_wizard ;;
      4) setup_ssl ;;
      5) configure_firewall; configure_fail2ban ;;
      6) install_composer; install_nvm ;;
      7) install_docker ;;
      8) newsite ;;
      9) vhost_add ;;
     10) break ;;
    esac
  done
}

# ─── CLI Flags ──────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: sudo $SCRIPT_NAME [options]

Options:
  -n, --dry-run     Show commands without executing
  -v, --verbose     Enable verbose output
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

# ─── Entry Point ───────────────────────────────────────────────────────────
pre_checks
main_menu
echo -e "${GREEN}Goodbye!${RESET}"
