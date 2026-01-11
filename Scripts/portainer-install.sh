#!/bin/bash

# Portainer CE Installation Script
# Deploys Portainer using the official LTS compose file
# Version: 1.1.0

# DIRECTORY ANCHOR
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

# VISUAL STYLING
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

# HELPER FUNCTIONS
print_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

print_line() {
    echo -e "${BLUE}===================================================================${NC}"
}

# HEADER
clear
print_line
echo -e "${CYAN}                    PORTAINER CE INSTALLER                         ${NC}"
print_line
echo ""

# DEPENDENCY CHECKS
check_dependencies() {
    local missing=()

    print_info "Checking dependencies..."

    if ! command -v curl &>/dev/null; then
        missing+=("curl")
    fi

    if ! command -v docker &>/dev/null; then
        missing+=("docker")
    fi

    if command -v docker &>/dev/null; then
        if ! docker compose version &>/dev/null; then
            missing+=("docker-compose-plugin")
        fi
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        print_error "Missing dependencies: ${missing[*]}"
        echo ""
        print_info "Please install the missing components first."
        if [[ " ${missing[*]} " =~ " docker " ]]; then
            print_info "Use 'Install Docker Engine' from the menu."
        fi
        return 1
    fi

    print_success "All dependencies satisfied."
    return 0
}

check_docker_running() {
    print_info "Checking Docker daemon..."

    if ! docker info &>/dev/null; then
        print_error "Docker daemon is not running or not accessible."
        echo ""
        print_info "Try one of the following:"
        echo "  - Start Docker: sudo systemctl start docker"
        echo "  - Add user to docker group: sudo usermod -aG docker \$USER"
        echo "  - Run this script with sudo"
        return 1
    fi

    print_success "Docker daemon is running."
    return 0
}

check_existing_portainer() {
    print_info "Checking for existing Portainer installation..."

    local compose_file="/opt/portainer/portainer-compose.yaml"
    if [ -f "$compose_file" ]; then
        print_warn "Existing Portainer compose deployment detected."
        echo ""
        echo "Options:"
        echo "  1) Remove and reinstall (will preserve data volume)"
        echo "  2) Cancel installation"
        echo ""
        read -rp "  Select option [1-2]: " choice

        case "$choice" in
            1)
                print_info "Removing existing deployment..."
                (cd /opt/portainer && docker compose -f "$compose_file" down) &>/dev/null
                print_success "Existing deployment removed."
                return 0
                ;;
            *)
                print_info "Installation cancelled."
                return 1
                ;;
        esac
    fi

    if docker ps -a --format '{{.Names}}' | grep -q "^portainer$"; then
        local status
        status=$(docker inspect -f '{{.State.Status}}' portainer 2>/dev/null)

        print_warn "Portainer container already exists (Status: $status)"
        echo ""
        echo "Options:"
        echo "  1) Remove and reinstall"
        echo "  2) Cancel installation"
        echo ""
        read -rp "  Select option [1-2]: " choice

        case "$choice" in
            1)
                print_info "Removing existing Portainer..."
                docker stop portainer &>/dev/null
                docker rm portainer &>/dev/null
                print_success "Existing container removed."
                return 0
                ;;
            *)
                print_info "Installation cancelled."
                return 1
                ;;
        esac
    fi

    return 0
}

# Validate compose file structure
validate_compose_file() {
    local compose_file="$1"

    print_info "Validating compose file..."

    if [ ! -f "$compose_file" ]; then
        print_error "Compose file not found."
        return 1
    fi

    if [ ! -s "$compose_file" ]; then
        print_error "Compose file is empty."
        return 1
    fi

    # Check for expected Portainer service definition
    if ! grep -q "portainer" "$compose_file"; then
        print_error "Compose file does not contain expected Portainer service."
        return 1
    fi

    # Check for portainer image reference
    if ! grep -qE "portainer/portainer-ce" "$compose_file"; then
        print_error "Compose file does not reference official Portainer CE image."
        return 1
    fi

    # Validate YAML syntax using docker compose
    if ! $SUDO docker compose -f "$compose_file" config &>/dev/null; then
        print_error "Compose file has invalid YAML syntax."
        return 1
    fi

    print_success "Compose file validated."
    return 0
}

deploy_portainer() {
    local compose_url="https://downloads.portainer.io/ce-lts/portainer-compose.yaml"
    local compose_dir="/opt/portainer"
    local compose_file="$compose_dir/portainer-compose.yaml"

    echo ""
    print_info "Deploying Portainer CE (LTS)..."

    if [ ! -w "/opt" ]; then
        if [ "$EUID" -ne 0 ]; then
            print_warn "Root privileges required to create $compose_dir"
            read -rp "  Use sudo for directory creation? (Y/n): " use_sudo
            use_sudo="${use_sudo:-y}"
            if [[ ! "$use_sudo" =~ ^[Yy]$ ]]; then
                print_info "Cancelled."
                return 1
            fi
            SUDO="sudo"
        else
            SUDO=""
        fi
    else
        SUDO=""
    fi

    print_info "Creating directory: $compose_dir"
    $SUDO mkdir -p "$compose_dir"
    if [ $? -ne 0 ]; then
        print_error "Failed to create directory."
        return 1
    fi

    print_info "Downloading Portainer compose file..."
    print_info "Source: $compose_url"

    if $SUDO curl -fsSL "$compose_url" -o "$compose_file"; then
        print_success "Compose file downloaded."
    else
        print_error "Failed to download compose file."
        return 1
    fi

    # Validate the downloaded file
    if ! validate_compose_file "$compose_file"; then
        print_error "Downloaded compose file failed validation."
        print_warn "The file may have been corrupted or the source may be compromised."
        $SUDO rm -f "$compose_file"
        return 1
    fi

    print_info "Starting Portainer containers..."
    echo ""

    cd "$compose_dir" || return 1

    if $SUDO docker compose -f "$compose_file" up -d; then
        echo ""
        print_success "Portainer deployed successfully!"
    else
        print_error "Failed to deploy Portainer."
        return 1
    fi

    return 0
}

show_access_info() {
    echo ""
    print_line
    echo -e "${WHITE}                      ACCESS INFORMATION                          ${NC}"
    print_line
    echo ""

    local ip_addr="localhost"
    if command -v ip &>/dev/null; then
        ip_addr=$(ip -4 addr show scope global 2>/dev/null | awk '/inet / {print $2; exit}' | cut -d/ -f1)
    elif command -v hostname &>/dev/null; then
        ip_addr=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    ip_addr="${ip_addr:-localhost}"

    echo -e "  ${WHITE}Portainer Web UI:${NC}"
    echo ""
    echo -e "    HTTPS: ${YELLOW}https://${ip_addr}:9443${NC}"
    echo -e "    HTTP:  ${YELLOW}http://${ip_addr}:9000${NC}"
    echo ""
    echo -e "  ${WHITE}Notes:${NC}"
    echo "    - First access will prompt you to create an admin account"
    echo "    - HTTPS uses a self-signed certificate (browser warning expected)"
    echo "    - Compose file location: /opt/portainer/portainer-compose.yaml"
    echo ""
    echo -e "  ${WHITE}Management Commands:${NC}"
    echo "    Stop:    docker compose -f /opt/portainer/portainer-compose.yaml down"
    echo "    Start:   docker compose -f /opt/portainer/portainer-compose.yaml up -d"
    echo "    Logs:    docker logs portainer"
    echo ""
    print_line
}

# MAIN
main() {
    if ! check_dependencies; then
        echo ""
        exit 1
    fi

    echo ""

    if ! check_docker_running; then
        echo ""
        exit 1
    fi

    echo ""

    if ! check_existing_portainer; then
        echo ""
        exit 0
    fi

    if deploy_portainer; then
        show_access_info
    else
        echo ""
        print_error "Portainer installation failed."
        exit 1
    fi
}

main
