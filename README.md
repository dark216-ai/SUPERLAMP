# SUPERLAMP — All-in-One LAMP + SUPER Stack Installer & Service Manager
#### Author: Bocaletto Luca

LAMPFM is a Bash “app” for Debian/Ubuntu that automates installation of a full LAMP stack plus FTP & Mail (FM), Node, and provides an interactive service manager for developers.

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
