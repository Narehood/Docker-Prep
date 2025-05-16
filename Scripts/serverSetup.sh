#!/bin/bash

# Function to detect the OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS="redhat"
        VERSION=$(rpm -q --queryformat '%{VERSION}' centos-release)
    elif [ -f /etc/debian_version ]; then
        OS="debian"
        VERSION=$(cat /etc/debian_version)
    elif grep -q "Alpine Linux" /etc/os-release; then
        OS="alpine"
        VERSION=$(cat /etc/alpine-release)
    else
        OS=$(uname -s)
        VERSION=$(uname -r)
    fi
}

# Function to install Docker using apk (Alpine)
install_docker_apk() {
    REPO_URL="https://dl-cdn.alpinelinux.org/alpine/edge/community"
    if ! grep -q "$REPO_URL" /etc/apk/repositories; then
        echo "$REPO_URL" >> /etc/apk/repositories
    fi
    sudo apk update
    sudo apk add docker
    sudo rc-update add docker default
    sudo service docker start
    sudo addgroup $(whoami) docker
}

# Function to install Docker using pacman (Arch)
install_docker_pacman() {
    sudo pacman -Syu --noconfirm docker
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
}

# Function to install Docker using apt (Debian/Ubuntu)
install_docker_apt() {
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
    docker --version
}

# Function to install Docker using dnf (Fedora)
install_docker_dnf() {
    REPO_URL="/etc/yum.repos.d/docker-ce.repo"
    if [ ! -f "$REPO_URL" ]; then
        sudo dnf -y install dnf-plugins-core
        sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    fi
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
}

# Function to install Docker using yum (CentOS/RHEL/Rocky/Alma)
install_docker_yum() {
    REPO_URL="/etc/yum.repos.d/docker-ce.repo"
    if [ ! -f "$REPO_URL" ]; then
        sudo yum install -y yum-utils
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    fi
    sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
}

# Function to install Docker using zypper (SUSE)
install_docker_zypper() {
    sudo zypper refresh
    sudo zypper install -y docker
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
}

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Installing Docker..."
    detect_os
    case "$OS" in
        alpine)
            install_docker_apk
            ;;
        arch)
            install_docker_pacman
            ;;
        debian|ubuntu)
            install_docker_apt
            ;;
        fedora)
            install_docker_dnf
            ;;
        redhat|centos|rocky|almalinux)
            install_docker_yum
            ;;
        suse)
            install_docker_zypper
            ;;
        *)
            echo "Unsupported system. Please install Docker manually."
            exit 1
            ;;
    esac
else
    echo "Docker is already installed. Skipping Docker installation."
fi

# Ask the user if they want to install Portainer
read -p "Would you like to install Portainer? (y/N): " install_portainer
install_portainer=${install_portainer:-n}

if [ "$install_portainer" == "y" ]; then
    sudo docker volume create portainer_data
    sudo docker run -d -p 9000:9000 --name=portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce

    # Get the IP address of the machine
    IP_ADDRESS=$(hostname -I | awk '{print $1}')

    echo "Portainer installation complete. You can access it at http://$IP_ADDRESS:9000 or your domain if configured."
else
    echo "Skipping Portainer installation."
fi

echo "Docker installation is complete. You should add the docker group to a non-root user for running Docker commands."
