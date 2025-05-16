<p align="center">
  <a href="https://github.com/Narehood/Docker-Prep" title="Go to GitHub repo">
    <img src="https://img.shields.io/static/v1?label=Narehood&message=Docker-Prep&color=blue&logo=github" alt="Narehood - Docker-Prep" />
  </a>
  <a href="https://github.com/Narehood/Docker-Prep">
    <img src="https://img.shields.io/github/stars/Narehood/Docker-Prep?style=social" alt="stars - Docker-Prep" />
  </a>
  <a href="https://github.com/Narehood/Docker-Prep">
    <img src="https://img.shields.io/github/forks/Narehood/Docker-Prep?style=social" alt="forks - Docker-Prep" />
  </a>
  <a href="https://github.com/Narehood/Docker-Prep/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-blue" alt="License" />
  </a>
  <a href="https://github.com/Narehood/Docker-Prep/issues">
    <img src="https://img.shields.io/github/issues/Narehood/Docker-Prep" alt="issues - Docker-Prep" />
  </a>
  <img src="https://img.shields.io/badge/bash_script-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white" alt="Bash Script" />
</p>

---

# Docker-Prep

**Docker-Prep** is a Bash script that automates the setup of a secure Docker environment on a fresh Linux system. It detects your Linux distribution, installs Docker using the appropriate package manager, creates a dedicated user for Docker, and (optionally) installs [Portainer](https://www.portainer.io/) for easy container management.

> **Tested on:** Ubuntu, Debian, Fedora, CentOS, RHEL, Rocky, Alma, Arch, SUSE, Alpine  
> _Should work on most modern Linux distributions._

---

## Table of Contents

- [What Does This Script Do?](#what-does-this-script-do)
- [Features](#features)
- [Installation & Usage](#installation--usage)
- [Menu Options](#menu-options)
- [Notes](#notes)
- [License](#license)

---

## What Does This Script Do?

- **Detects your Linux distribution** and installs Docker using the correct method.
- **Creates a new user** (or lets you add an existing user) for Docker usage.
- **Adds the user to the Docker group** for non-root Docker access.
- **Optionally installs Portainer**, a web UI for managing Docker containers.
- **Guides you through each step** with clear prompts.

---

## Features

- 🐳 **Automatic Docker installation** (supports most major Linux distros)
- 👤 **Creates a dedicated Docker user** and sets a password
- 🔒 **Adds user to Docker group** for secure, non-root Docker usage
- 🌐 **Optional Portainer installation** for easy container management
- 📝 **Interactive prompts** for user creation and configuration

---

## Installation & Usage

Clone the repository and run the main script:

```sh
git clone https://github.com/Narehood/Docker-Prep
cd Docker-Prep
bash install.sh
```

**Follow the on-screen instructions** to:

- Install Docker (if not already installed)
- Create a new user for Docker (or add an existing user)
- Add the user to the Docker group
- Optionally install Portainer

---

## Menu Options

During the script execution, you will be prompted to:

1. **Install Docker** (automatically detects your OS and uses the correct method)
2. **Create a new user** for Docker access (or add an existing user)
3. **Set a password** for the new user
4. **Add the user to the Docker group**
5. **Install Portainer** (optional)

---

## Notes

- This script is intended for personal projects and may require adjustments for production or enterprise environments.
- Always review scripts before running them on critical systems.
- If you encounter issues, please open an [issue](https://github.com/Narehood/Docker-Prep/issues).

---

## License

This project is licensed under the [MIT License](https://github.com/Narehood/Docker-Prep/blob/main/LICENSE).

---

> _You are free to use and modify this script as you wish. Bug reports are welcome, but fixes are not guaranteed._
