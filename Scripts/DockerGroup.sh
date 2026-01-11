#!/bin/bash

# Docker Group Management Script
# Adds a user to the docker group for rootless container management
# REQUIRES_ROOT: true
# DESCRIPTION: Add a user to the docker group

# DIRECTORY ANCHOR
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/$(basename -- "${BASH_SOURCE[0]}")"

# VISUAL STYLING
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

# print_info prints an informational message prefixed with a cyan `[INFO]` tag.
print_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
# print_success prints a green "[OK]" prefix followed by the given message to stdout.
print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
# print_error prints an error message prefixed with "[ERROR]" in red and resets the terminal color afterward.
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
# print_warn prints a warning message prefixed with "[WARN]" using the YELLOW color and resets the terminal color.
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# print_line prints a blue separator line to stdout using the $BLUE color and resets color with $NC.
print_line() {
    echo -e "${BLUE}===================================================================${NC}"
}

# HEADER
clear
print_line
echo -e "${CYAN}                  DOCKER GROUP MANAGEMENT                          ${NC}"
print_line
echo ""

# ROOT CHECK
if [[ "$EUID" -ne 0 ]]; then
    print_error "This script must be run as root (sudo)."
    exit 1
fi

# detect_os sets the global `OS` variable to the detected operating system identifier (prefers `/etc/os-release` ID, falls back to common distro files or the lowercased system name).
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

# check_docker_installed checks whether Docker is available; if not, it prints an error and informational message and exits with status 1.
check_docker_installed() {
    if ! command -v docker &>/dev/null; then
        print_error "Docker is not installed."
        print_info "Please install Docker first using the Docker Host Preparation menu."
        exit 1
    fi
    print_success "Docker is installed."
}

# ensure_docker_group ensures the `docker` group exists on the system, creating it with `addgroup` on Alpine or `groupadd` on other OSes and exiting with status 1 if creation fails.
ensure_docker_group() {
    if ! getent group docker &>/dev/null; then
        print_warn "Docker group does not exist. Creating it..."
        case "$OS" in
            alpine)
                addgroup docker
                ;;
            *)
                groupadd docker
                ;;
        esac

        if getent group docker &>/dev/null; then
            print_success "Docker group created."
        else
            print_error "Failed to create docker group."
            exit 1
        fi
    else
        print_success "Docker group exists."
    fi
}

# add_user_to_docker_group adds a user to the docker group using an OS-appropriate command and returns 0 on success or 1 on failure.
add_user_to_docker_group() {
    local username="$1"

    print_info "Adding '$username' to docker group..."

    case "$OS" in
        alpine)
            if addgroup "$username" docker 2>/dev/null; then
                return 0
            else
                return 1
            fi
            ;;
        *)
            if usermod -aG docker "$username" 2>/dev/null; then
                return 0
            else
                return 1
            fi
            ;;
    esac
}

# user_in_docker_group checks whether the specified user is a member of the docker group.
user_in_docker_group() {
    local username="$1"
    groups "$username" 2>/dev/null | grep -qw docker
}

# show_docker_group_members prints the current members of the 'docker' group, or "(none)" if the group has no members.
show_docker_group_members() {
    echo ""
    print_info "Current docker group members:"
    local members
    members=$(getent group docker | cut -d: -f4)
    if [[ -n "$members" ]]; then
        echo -e "  ${YELLOW}$members${NC}"
    else
        echo -e "  ${YELLOW}(none)${NC}"
    fi
    echo ""
}

# MAIN LOGIC
check_docker_installed
echo ""
ensure_docker_group
show_docker_group_members

# Get username
default_user="${SUDO_USER:-}"
if [[ -n "$default_user" ]]; then
    read -rp "Enter username to add to docker group [$default_user]: " username
    username="${username:-$default_user}"
else
    read -rp "Enter username to add to docker group: " username
fi

# Validate input
if [[ -z "$username" ]]; then
    print_error "No username provided."
    exit 1
fi

# Check if user exists
if ! id "$username" &>/dev/null; then
    print_error "User '$username' does not exist."
    echo ""
    print_info "Available users:"
    awk -F: '$3 >= 1000 && $3 < 65534 {print "  " $1}' /etc/passwd
    exit 1
fi

print_success "User '$username' exists."

# Check if already in group
if user_in_docker_group "$username"; then
    print_warn "User '$username' is already in the docker group."
    echo ""
    print_info "If docker commands still require sudo, try:"
    echo "  - Log out and log back in"
    echo "  - Run: newgrp docker"
    echo "  - Reboot the system"
    exit 0
fi

# Add user to group
if add_user_to_docker_group "$username"; then
    echo ""
    print_success "User '$username' has been added to the docker group."
    echo ""
    print_line
    echo -e "${WHITE}                        IMPORTANT                                 ${NC}"
    print_line
    echo ""
    echo -e "  For changes to take effect, the user must:"
    echo ""
    echo -e "    ${CYAN}Option 1:${NC} Log out and log back in"
    echo ""
    echo -e "    ${CYAN}Option 2:${NC} Run this command in the current session:"
    echo -e "              ${YELLOW}newgrp docker${NC}"
    echo ""
    echo -e "    ${CYAN}Option 3:${NC} Reboot the system"
    echo ""
    print_line
else
    print_error "Failed to add '$username' to docker group."
    exit 1
fi