<div align="center">

# 🐳 Docker-Prep

<p>
  <img src="https://img.shields.io/github/license/Narehood/Docker-Prep?style=for-the-badge&color=blue" alt="License" />
  <img src="https://img.shields.io/github/last-commit/Narehood/Docker-Prep?style=for-the-badge&color=orange" alt="Last Commit" />
  <img src="https://img.shields.io/badge/Bash-Script-black?style=for-the-badge&logo=gnu-bash" alt="Bash" />
</p>

<p>
  <a href="https://github.com/Narehood/Docker-Prep/stargazers"><img src="https://img.shields.io/github/stars/Narehood/Docker-Prep?style=social" alt="Stars" /></a>
  <a href="https://github.com/Narehood/Docker-Prep/network/members"><img src="https://img.shields.io/github/forks/Narehood/Docker-Prep?style=social" alt="Forks" /></a>
  <a href="https://github.com/Narehood/Docker-Prep/issues"><img src="https://img.shields.io/github/issues/Narehood/Docker-Prep?style=social" alt="Issues" /></a>
</p>

**Automated Docker Environment Configuration for Linux**

Detects your OS, installs the official Docker Engine, creates dedicated users with correct permissions,<br>
and optionally deploys Portainer for immediate container management.

[Features](#-features) • [Quick Start](#-quick-start) • [Capabilities](#-capabilities) • [Notes](#%EF%B8%8F-important-notes)

</div>

---

## 🐧 Supported Distributions

<div align="center">
  <img src="https://img.shields.io/badge/Ubuntu-E95420?style=flat-square&logo=ubuntu&logoColor=white" alt="Ubuntu" />
  <img src="https://img.shields.io/badge/Debian-A81D33?style=flat-square&logo=debian&logoColor=white" alt="Debian" />
  <img src="https://img.shields.io/badge/Alpine_Linux-0D597F?style=flat-square&logo=alpine-linux&logoColor=white" alt="Alpine" />
  <img src="https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=arch-linux&logoColor=white" alt="Arch" />
  <img src="https://img.shields.io/badge/Fedora-294172?style=flat-square&logo=fedora&logoColor=white" alt="Fedora" />
  <img src="https://img.shields.io/badge/RHEL/CentOS-262525?style=flat-square&logo=redhat&logoColor=white" alt="RHEL" />
  <img src="https://img.shields.io/badge/openSUSE-73BA25?style=flat-square&logo=opensuse&logoColor=white" alt="SUSE" />
</div>

---

## ⚡ Quick Start

```bash
git clone https://github.com/Narehood/Docker-Prep
cd Docker-Prep
bash install.sh
```

---

## 🚀 Features

| Feature | Description |
| :--- | :--- |
| **Auto-Detection** | Identifies your distro and installs the correct Docker Engine package |
| **User Management** | Creates a dedicated Docker user or configures existing users for rootless access |
| **Permission Fix** | Automatically handles group assignments (`usermod -aG docker`) |
| **Portainer Ready** | Option to instantly deploy [Portainer](https://www.portainer.io/) via the script |
| **Secure Defaults** | Ensures proper service enabling and user permission handling |

---

## 📋 Capabilities

The script guides you through a simplified menu to perform the following:

| Action | Description |
| :--- | :--- |
| **Install Docker Engine** | Updates repositories, installs dependencies, and sets up the Docker daemon |
| **User Configuration** | Creates a new user specifically for Docker or adds your current user |
| **Security Groups** | Adds the selected user to the `docker` group for non-root command execution |
| **Portainer Deployment** | Pulls and runs the Portainer CE container on port 9443 |

---

## ⚠️ Important Notes

| Note | Details |
| :--- | :--- |
| **Root Access** | Script must be run as root or with `sudo` privileges |
| **Re-Login Required** | Log out and back in after adding a user to the Docker group |
| **Portainer** | If installed, accessible at `https://<your-ip>:9443` |

---

<div align="center">

*Licensed under the [MIT License](https://github.com/Narehood/Docker-Prep/blob/main/LICENSE).*<br>
*You are free to use and modify this script as you wish.*

</div>
