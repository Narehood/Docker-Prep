#!/bin/bash

# User Creation Script
# Creates a new user with optional docker group membership
# REQUIRES_ROOT: true
# DESCRIPTION: Create a new system user

# DIRECTORY ANCHOR
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"

# VISUAL STYLING
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

# print_info prints an informational message prefixed with "[INFO]" in cyan.
print_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
# print_success prints a success message prefixed with a green "[OK]" tag followed by the provided message.
print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
# print_error prints MESSAGE prefixed with "[ERROR]" in red and resets terminal color.
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
# print_warn prints a warning message prefixed with `[WARN]` in yellow to stdout.
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# print_line prints a blue horizontal separator line to stdout.
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

# detect_os detects the host operating system and sets the global variable `OS` to a lowercase identifier (e.g., "ubuntu", "debian", "rhel") or "unknown" if detection fails.
detect_os() {
    OS="unknown"
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS="${ID,,}"
    elif [[ -f /etc/redhat-release ]]; then
        OS="rhel"
    elif [[ -f /etc/debian_version ]]; then
        OS="debian"
    else
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    fi

    # Normalize redhat variants to rhel
    if [[ "$OS" == "redhat" ]]; then
        OS="rhel"
    fi
}

detect_os
echo -e "${WHITE}Detected OS:${NC} $OS"
echo ""

# validate_os verifies that the detected OS is one of the supported distributions and prints a success message; if the OS is unsupported it prints an error and exits with status 1.
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

# create_user creates a system user with the given username using the OS's preferred user-creation command.
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
            useradd -m -s /bin/bash "$username"
            ;;
        *)
            print_error "Unsupported OS for user creation."
            exit 1
            ;;
    esac
}

# set_password prompts for and applies a password for the specified user; exits with code 1 if setting the password fails.
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

# add_to_docker_group prompts whether to add a user to the docker group and, if confirmed, adds the user using OS-specific commands.
# If the docker group does not exist the function warns and returns; after attempting to add the user it verifies membership and reports success or failure.
add_to_docker_group() {
    local username="$1"
    local add_docker
    local docker_group_exists=false

    echo ""
    read -rp "Add '$username' to docker group? [y/N]: " add_docker
    
    if [[ "$add_docker" =~ ^[Yy]$ ]]; then
        # Check for docker group existence with fallback for missing getent
        if command -v getent &>/dev/null; then
            getent group docker &>/dev/null && docker_group_exists=true
        elif [[ -f /etc/group ]]; then
            grep -q "^docker:" /etc/group && docker_group_exists=true
        else
            print_warn "Unable to verify docker group (getent unavailable, /etc/group missing)."
            print_info "Skipping docker group membership."
            return
        fi

        if [[ "$docker_group_exists" != true ]]; then
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

        # Verify membership using id (more reliable than groups command)
        if id -nG "$username" 2>/dev/null | tr ' ' '\n' | grep -qx "docker"; then
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
