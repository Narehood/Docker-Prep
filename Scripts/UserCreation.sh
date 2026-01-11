#!/bin/bash

# User Creation Script
# Creates a new user with optional docker group membership
# REQUIRES_ROOT: true
# DESCRIPTION: Create a new system user

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
echo -e "${CYAN}                      USER CREATION                                ${NC}"
print_line
echo ""

# ROOT CHECK
if [[ "$EUID" -ne 0 ]]; then
    print_error "This script must be run as root (sudo)."
    exit 1
fi

# OS DETECTION
detect_os() {
    OS="unknown"
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS="$ID"
    elif [[ -f /etc/redhat-release ]]; then
        OS="redhat"
    elif [[ -f /etc/debian_version ]]; then
        OS="debian"
    else
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    fi
}

detect_os
echo -e "${WHITE}Detected OS:${NC} $OS"
echo ""

# Validate OS support
validate_os() {
    case "$OS" in
        ubuntu|debian|centos|rhel|fedora|rocky|almalinux|alpine)
            print_success "Supported OS detected."
            ;;
        *)
            print_error "Unsupported Linux distribution: $OS"
            exit 1
            ;;
    esac
}

validate_os
echo ""

# Get username
read -rp "Enter username to create: " username

if [[ -z "$username" ]]; then
    print_error "No username provided."
    exit 1
fi

# Validate username format
if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    print_error "Invalid username format."
    print_info "Username must start with a letter or underscore and contain only lowercase letters, numbers, underscores, or hyphens."
    exit 1
fi

# Check if user already exists
if id "$username" &>/dev/null; then
    print_error "User '$username' already exists."
    exit 1
fi

# Create user based on OS
create_user() {
    local username="$1"

    print_info "Creating user '$username'..."

    case "$OS" in
        ubuntu|debian)
            adduser --disabled-password --gecos "" "$username"
            ;;
        alpine)
            adduser -D "$username"
            ;;
        centos|rhel|fedora|rocky|almalinux)
            useradd "$username"
            ;;
        *)
            print_error "Unsupported OS for user creation."
            exit 1
            ;;
    esac
}

# Set user password
set_password() {
    local username="$1"

    echo ""
    print_info "Set password for '$username':"
    if ! passwd "$username"; then
        print_error "Failed to set password."
        exit 1
    fi
    print_success "Password set successfully."
}

# Prompt for docker group membership
add_to_docker_group() {
    local username="$1"

    echo ""
    read -rp "Add '$username' to docker group? [y/N]: " add_docker
    
    if [[ "$add_docker" =~ ^[Yy]$ ]]; then
        if ! getent group docker &>/dev/null; then
            print_warn "Docker group does not exist."
            print_info "Install Docker first or run the Docker Group script later."
            return
        fi

        case "$OS" in
            alpine)
                addgroup "$username" docker
                ;;
            *)
                usermod -aG docker "$username"
                ;;
        esac

        if groups "$username" 2>/dev/null | grep -qw docker; then
            print_success "User '$username' added to docker group."
        else
            print_error "Failed to add user to docker group."
        fi
    else
        print_info "Skipping docker group membership."
    fi
}

# MAIN LOGIC
if create_user "$username"; then
    print_success "User '$username' created successfully."
else
    print_error "Failed to create user '$username'."
    exit 1
fi

set_password "$username"
add_to_docker_group "$username"

echo ""
print_line
echo -e "${GREEN}                    USER CREATION COMPLETE                         ${NC}"
print_line
echo ""
echo -e "  ${WHITE}Username:${NC} $username"
echo -e "  ${WHITE}Home:${NC}     /home/$username"
echo ""
print_line
