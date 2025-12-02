#!/bin/bash

# --- 1. DIRECTORY ANCHOR ---
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

# --- 2. VISUAL STYLING ---
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# --- 3. HELPER FUNCTIONS ---
print_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# --- 4. HEADER ---
clear
echo -e "${BLUE}===================================================================${NC}"
echo -e "${CYAN}             DOCKER ENVIRONMENT PREP & INSTALLER           ${NC}"
echo -e "${BLUE}===================================================================${NC}"
echo ""

# --- 5. ROOT CHECK ---
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root (sudo)."
    exit 1
fi

# --- 6. OS DETECTION ---
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

# --- 7. INSTALLATION FUNCTIONS ---

install_docker_apk() {
    print_info "Configuring Alpine repositories..."
    local ALPINE_VERSION=$(apk --version | head -n 1 | awk '{print $NF}' | cut -d- -f1 | cut -d'.' -f1,2)
    local REPO_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/community"

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
    
    # 1. Update and install prerequisites
    apt-get update -q
    apt-get install -y ca-certificates curl gnupg

    # 2. Setup Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    # Remove old key if it exists to avoid conflicts
    rm -f /etc/apt/keyrings/docker.gpg
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # 3. Add the repository
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID=$ID
        
        # Logic to map distro ID to the correct Docker repo (debian vs ubuntu)
        if [[ "$DISTRO_ID" == "ubuntu" || "$DISTRO_ID" == "pop" || "$DISTRO_ID" == "linuxmint" ]]; then
             REPO_TYPE="ubuntu"
        else
             # Default to debian for Kali, Raspbian, Debian, etc.
             REPO_TYPE="debian"
        fi
        
        # Get Codename reliably
        CODENAME=$(lsb_release -cs 2>/dev/null || grep VERSION_CODENAME /etc/os-release | cut -d= -f2)
        if [ -z "$CODENAME" ]; then
            # Fallback for systems like Kali Rolling which don't have standard codenames
            # "bookworm" is safe for modern Debian-based rolling distros
            CODENAME="bookworm"
        fi
        
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$REPO_TYPE \
          $CODENAME stable" | \
          tee /etc/apt/sources.list.d/docker.list > /dev/null
    fi

    # 4. Update and Install Official Packages
    apt-get update -q
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # 5. Enable Service
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

# --- 8. MAIN LOGIC ---

# Detect OS
detect_os
echo -e "${WHITE}Detected OS:${NC} $OS"

# Check/Install Docker
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker not found. Beginning installation...${NC}"
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
    
    if command -v docker &> /dev/null; then
        print_success "Docker Engine installed."
        # Check Compose
        if docker compose version &> /dev/null; then
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

# --- 9. USER PERMISSIONS ---
echo ""
echo -e "${WHITE}--- USER CONFIGURATION ---${NC}"
echo "Docker runs as root by default. To run without 'sudo', add a user to the group."
read -p "Enter username to add to 'docker' group (leave blank to skip): " DOCKER_USER

if [ -n "$DOCKER_USER" ]; then
    if id "$DOCKER_USER" &>/dev/null; then
        # Handle group adding based on OS tools
        if command -v usermod &> /dev/null; then
            usermod -aG docker "$DOCKER_USER"
        elif command -v addgroup &> /dev/null; then
            # Alpine usually
            addgroup "$DOCKER_USER" docker
        fi
        print_success "User '$DOCKER_USER' added to docker group."
        print_warn "User must log out and back in for this to take effect."
    else
        print_error "User '$DOCKER_USER' does not exist."
    fi
fi

# --- 10. PORTAINER SETUP ---
echo ""
echo -e "${WHITE}--- OPTIONAL COMPONENTS ---${NC}"
read -p "Install Portainer CE (Web UI)? (y/N): " install_portainer

if [[ "$install_portainer" =~ ^[Yy]$ ]]; then
    print_info "Deploying Portainer..."
    
    # Create Volume
    docker volume create portainer_data >/dev/null
    
    # Run Container (Exposing 9443 for HTTPS and 9000 for legacy HTTP)
    docker run -d -p 8000:8000 -p 9443:9443 -p 9000:9000 \
        --name=portainer --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce:latest

    # Get IP
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
    
    print_success "Portainer deployed."
    echo -e "Access via HTTPS: ${YELLOW}https://${IP_ADDRESS}:9443${NC}"
    echo -e "Access via HTTP:  ${YELLOW}http://${IP_ADDRESS}:9000${NC}"
else
    print_info "Skipping Portainer."
fi

echo ""
echo -e "${BLUE}===================================================================${NC}"
print_success "Docker Preparation Complete."
echo -e "${BLUE}===================================================================${NC}"
echo ""
