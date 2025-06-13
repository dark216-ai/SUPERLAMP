# SUPERLAMP — All-in-One LAMP + SUPER Stack Installer & Service Manager  
**Author:** Bocaletto Luca  

SUPERLAMP is a Bash “app” for Debian/Ubuntu that automates, in one TUI-driven tool:  
- Full LAMP stack (Apache2, MySQL/MariaDB, PHP + phpMyAdmin)  
- FTP client/server (lftp, vsftpd) & Mail server (Postfix)  
- Python 3 + pip/virtualenv, Git, build-essential & curl  
- Node.js LTS via NodeSource, plus Composer & NVM  
- Docker & Docker Compose  
- Firewall (UFW) and intrusion protection (Fail2Ban)  
- SSL provisioning (Certbot → Apache)  
- “Smart” system maintenance:  
  • TTL-based `apt update`  
  • retry/backoff on APT failures  
  • parallel downloads via `apt-fast`  
  • unattended-upgrades for security patches  
  • old-kernel cleanup & dist-upgrade  
- Interactive Whiptail TUI for:  
  • Selecting/installing components  
  • Service status & start/stop/restart/enable/disable  
  • Database setup wizard  
  • New-site scaffolding & Apache vhost creation  
- CLI flags: `--dry-run`, `--verbose`, `--help`  

With SUPERLAMP you get a battle-tested, developer-friendly stack installer and service manager—perfect for rapid setup, safe automation and ongoing maintenance.  

---

## 1. Features

- **Automated Installation**  

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

- **Service Manager**  
  • Detect which components are installed  
  • Show running/stopped status  
  • Start | Stop | Restart | Enable | Disable services  

- **Developer Utilities**  
  • Scaffold a new virtual‐host/site directory with sample PHP/Python files  
  • Easy `newsite` and `vhost` commands  

- **Modular & Safe**  
  • Installs only missing packages  
  • Non-interactive `DEBIAN_FRONTEND=noninteractive` mode  
  • Logs all actions to `/var/log/lampfm.log`

---

## 2. Components & APT Packages

| Component        | Package(s)                         |
|------------------|------------------------------------|
| Web Server       | `apache2`                          |
| Database Server  | `mysql-server` **or** `mariadb-server` |
| PHP              | `php`, `libapache2-mod-php`, `php-mysql`, `php-cli` |
| phpMyAdmin       | `phpmyadmin`                       |
| Python           | `python3`, `python3-pip`, `virtualenv` |
| FTP Client       | `lftp`                             |
| FTP Server       | `vsftpd`                           |
| Mail Server      | `postfix`                          |
| Version Control  | `git`                              |

---

## 3. CLI & Interactive Menu

After downloading `lampfm.sh`, these commands are available:

# Install all missing components
    sudo ./lampfm.sh install

# Show which packages are installed or missing
    sudo ./lampfm.sh status packages

# Show status of services (apache2, mysql, vsftpd, postfix, etc.)
    sudo ./lampfm.sh status services

# Start | Stop | Restart a service
    sudo ./lampfm.sh start apache2
    sudo ./lampfm.sh stop mysql
    sudo ./lampfm.sh restart vsftpd

# Enable | Disable service at boot
    sudo ./lampfm.sh enable postfix
    sudo ./lampfm.sh disable apache2

# Scaffold a new site
    sudo ./lampfm.sh newsite myproject

# Create & enable a vhost
    sudo ./lampfm.sh vhost add myproject.local /var/www/html/myproject

# Show help
    sudo ./lampfm.sh --help

## 4. Usage

### Download

    wget https://example.com/lampfm.sh -O lampfm.sh
    chmod +x lampfm.sh

### Install
    sudo ./lampfm.sh install

### Manage Services Use lampfm.sh status, start, stop, restart as needed.

### Developer Shortcuts Scaffold new sites or vhosts in one command.

5. Logging & Troubleshooting

    Log file: /var/log/lampfm.log

    Verbose mode: ./lampfm.sh install --verbose

    Errors are highlighted in red; successes in green.

#### When you’re ready, reply with continua and I will generate the complete lampfm.sh script.
