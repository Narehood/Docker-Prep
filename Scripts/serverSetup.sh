#!/bin/sh

# --- DIRECTORY ANCHOR ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- VISUAL STYLING ---
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

# --- HELPER FUNCTIONS ---
print_info() { printf "${CYAN}[INFO]${NC} %s\n" "$1"; }
print_success() { printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"; }
print_error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }
print_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }

# --- HEADER ---
clear
printf "${BLUE}===================================================================${NC}\n"
printf "${CYAN}             DOCKER ENVIRONMENT PREP & INSTALLER           ${NC}\n"
printf "${BLUE}===================================================================${NC}\n"
echo ""

# --- ROOT CHECK ---
if [ "$(id -u)" -ne 0 ]; then
    print_error "Please run as root (sudo)."
    exit 1
fi

# --- OS DETECTION ---
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS="redhat"
    elif [ -f /etc/debian_version ]; then
        OS="debian"
    else
        OS=$(uname -s)
    fi
}

# --- INSTALLATION FUNCTIONS ---

install_docker_apk() {
    print_info "Configuring Alpine repositories..."
    ALPINE_VERSION=$(cat /etc/alpine-release | cut -d'.' -f1,2)
    REPO_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/community"

    if ! grep -q "$REPO_URL" /etc/apk/repositories; then
        echo "$REPO_URL" >> /etc/apk/repositories
    fi

    print_info "Installing Docker & Compose via APK..."
    apk update
    apk add docker docker-cli-compose
    rc-update add docker default
    service docker start
}

install_docker_pacman() {
    print_info "Installing Docker & Compose via Pacman..."
    pacman -Syu --noconfirm docker docker-compose
    systemctl enable --now docker
}

install_docker_apt() {
    print_info "Installing Docker & Compose via APT (Official Repo)..."

    apt-get update -q
    apt-get install -y ca-certificates curl gnupg

    install -m 0755 -d /etc/apt/keyrings
    rm -f /etc/apt/keyrings/docker.gpg
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID=$ID

        case "$DISTRO_ID" in
            ubuntu|pop|linuxmint) REPO_TYPE="ubuntu" ;;
            *) REPO_TYPE="debian" ;;
        esac

        CODENAME=$(lsb_release -cs 2>/dev/null || grep VERSION_CODENAME /etc/os-release | cut -d= -f2)
        if [ -z "$CODENAME" ]; then
            CODENAME="bookworm"
        fi

        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$REPO_TYPE \
          $CODENAME stable" | \
          tee /etc/apt/sources.list.d/docker.list > /dev/null
    fi

    apt-get update -q
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    systemctl enable --now docker
}

install_docker_dnf() {
    print_info "Configuring Docker CE Repo..."
    if [ ! -f "/etc/yum.repos.d/docker-ce.repo" ]; then
        dnf -y install dnf-plugins-core
        dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    fi
    print_info "Installing Docker & Compose via DNF..."
    dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
}

install_docker_yum() {
    print_info "Configuring Docker CE Repo..."
    if [ ! -f "/etc/yum.repos.d/docker-ce.repo" ]; then
        yum install -y yum-utils
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    fi
    print_info "Installing Docker & Compose via Yum..."
    yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
}

install_docker_zypper() {
    print_info "Installing Docker via Zypper..."
    zypper refresh
    zypper install -y docker docker-compose
    systemctl enable --now docker
}

# --- MAIN LOGIC ---

detect_os
printf "${WHITE}Detected OS:${NC} %s\n" "$OS"

if ! command -v docker > /dev/null 2>&1; then
    printf "${YELLOW}Docker not found. Beginning installation...${NC}\n"
    case "$OS" in
        alpine) install_docker_apk ;;
        arch|manjaro) install_docker_pacman ;;
        debian|ubuntu|kali|pop|linuxmint) install_docker_apt ;;
        fedora) install_docker_dnf ;;
        redhat|centos|rocky|almalinux) install_docker_yum ;;
        suse|opensuse*) install_docker_zypper ;;
        *)
            print_error "Unsupported system ($OS). Please install Docker manually."
            exit 1
            ;;
    esac

    if command -v docker > /dev/null 2>&1; then
        print_success "Docker Engine installed."
        if docker compose version > /dev/null 2>&1; then
            print_success "Docker Compose (Plugin) installed."
        else
            print_warn "Docker installed, but 'docker compose' command failed."
        fi
    else
        print_error "Docker installation failed."
        exit 1
    fi
else
    print_success "Docker is already installed."
fi

# --- USER PERMISSIONS ---
echo ""
printf "${WHITE}--- USER CONFIGURATION ---${NC}\n"
echo "Docker runs as root by default. To run without 'sudo', add a user to the group."
printf "Enter username to add to 'docker' group (leave blank to skip): "
read DOCKER_USER

if [ -n "$DOCKER_USER" ]; then
    if id "$DOCKER_USER" > /dev/null 2>&1; then
        if command -v usermod > /dev/null 2>&1; then
            usermod -aG docker "$DOCKER_USER"
        elif command -v addgroup > /dev/null 2>&1; then
            addgroup "$DOCKER_USER" docker
        fi
        print_success "User '$DOCKER_USER' added to docker group."
        print_warn "User must log out and back in for this to take effect."
    else
        print_error "User '$DOCKER_USER' does not exist."
    fi
fi

# --- PORTAINER SETUP ---
echo ""
printf "${WHITE}--- OPTIONAL COMPONENTS ---${NC}\n"
printf "Install Portainer CE (Web UI)? (y/N): "
read install_portainer

case "$install_portainer" in
    y|Y)
        print_info "Deploying Portainer..."

        docker volume create portainer_data > /dev/null

        docker run -d -p 8000:8000 -p 9443:9443 -p 9000:9000 \
            --name=portainer --restart=always \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v portainer_data:/data \
            portainer/portainer-ce:latest

        IP_ADDRESS=$(hostname -I | awk '{print $1}')

        print_success "Portainer deployed."
        printf "Access via HTTPS: ${YELLOW}https://%s:9443${NC}\n" "$IP_ADDRESS"
        printf "Access via HTTP:  ${YELLOW}http://%s:9000${NC}\n" "$IP_ADDRESS"
        ;;
    *)
        print_info "Skipping Portainer."
        ;;
esac

echo ""
printf "${BLUE}===================================================================${NC}\n"
print_success "Docker Preparation Complete."
printf "${BLUE}===================================================================${NC}\n"
echo ""
