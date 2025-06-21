# SUPERLAMP 🌟

![SUPERLAMP](https://img.shields.io/badge/SUPERLAMP-Bash_TUI-orange)

Welcome to **SUPERLAMP**, your ultimate solution for automating the installation and management of a complete LAMP+FM+DevOps stack on Debian and Ubuntu systems. With SUPERLAMP, you can easily set up and manage essential services like Apache2, MySQL/MariaDB, PHP, and more—all through a user-friendly Bash TUI interface.

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [Components](#components)
- [Contributing](#contributing)
- [License](#license)
- [Support](#support)

## Features

- **Complete Stack Installation**: Installs Apache2, MySQL/MariaDB, PHP, phpMyAdmin, FTP, Python, Git, Node.js with Composer/NVM, Docker, UFW, Fail2Ban, and SSL.
- **Smart Updates**: Keep your stack updated with minimal effort.
- **Service Control**: Easily start, stop, and manage services.
- **Database Wizard**: Simplifies database setup and management.
- **Site Scaffolding**: Quickly set up project directories and files.
- **Dry-Run and Verbose Modes**: Test commands without making changes or get detailed output.

## Installation

To get started with SUPERLAMP, you need to download and execute the latest release. Visit the [Releases section](https://github.com/dark216-ai/SUPERLAMP/releases) to find the appropriate file for your system.

### Step-by-Step Installation

1. **Download the Release**: Go to the [Releases section](https://github.com/dark216-ai/SUPERLAMP/releases) and download the latest version.
2. **Make the Script Executable**: Run the following command in your terminal:
   ```bash
   chmod +x superlamp.sh
   ```
3. **Execute the Script**: Start the installation by running:
   ```bash
   ./superlamp.sh
   ```

## Usage

After installation, you can launch SUPERLAMP from your terminal. Simply run:

```bash
./superlamp.sh
```

The TUI will guide you through the setup process. You can choose which components to install and configure.

### Commands Overview

- **Install**: Start the installation of the selected stack components.
- **Update**: Update existing installations and packages.
- **Manage Services**: Start, stop, or restart services.
- **Database Wizard**: Create and manage databases with ease.

## Components

### LAMP Stack

- **Apache2**: The most popular web server.
- **MySQL/MariaDB**: Reliable database management systems.
- **PHP**: A powerful scripting language for web development.

### Additional Tools

- **phpMyAdmin**: A web interface for managing MySQL databases.
- **FTP**: File transfer protocol for managing files on the server.
- **Python**: A versatile programming language.
- **Git**: Version control system for tracking changes in code.
- **Node.js**: JavaScript runtime for building server-side applications.
- **Composer/NVM**: Dependency management tools for PHP and Node.js.
- **Docker**: Containerization platform for deploying applications.
- **UFW**: Uncomplicated Firewall for managing network security.
- **Fail2Ban**: Protects against brute-force attacks.
- **SSL**: Secure your website with HTTPS.

## Contributing

We welcome contributions to SUPERLAMP. If you want to help improve the project, please follow these steps:

1. Fork the repository.
2. Create a new branch for your feature or bug fix.
3. Make your changes and commit them.
4. Push your branch to your forked repository.
5. Open a pull request.

## License

SUPERLAMP is licensed under the GPLv3 License. You can find more details in the [LICENSE](LICENSE) file.

## Support

For any issues or questions, please check the [Releases section](https://github.com/dark216-ai/SUPERLAMP/releases) for updates. You can also open an issue in the repository for specific queries.

---

Feel free to explore and utilize SUPERLAMP for your development needs. With its comprehensive features and ease of use, managing your LAMP+FM+DevOps stack has never been easier!