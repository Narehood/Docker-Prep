#!/bin/bash
set -euo pipefail

# Portainer CE Installation Script
# Deploys Portainer using the official LTS compose file
# Version: 1.2.0
# DESCRIPTION: Install Portainer CE using the official LTS compose file

# DIRECTORY ANCHOR
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
# Image digest pinned from the Portainer CE LTS release channel (not a floating tag).
readonly PORTAINER_IMAGE="portainer/portainer-ce@sha256:f6bc23d1695530a609563fd65c180aaafec0fc02e019d5fc63d16b6fbe83addd"
# SHA-256 of the official ce-lts compose file from downloads.portainer.io (pre-pin content).
readonly PORTAINER_COMPOSE_SHA256="3929fa6576ad9f523297a69e8764bc112b5b8b3f67d986f1c2afed60248e1c22"
SUDO=""

# VISUAL STYLING
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

# print_info prints an informational message prefixed with `[INFO]` in cyan.
print_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
# print_success prints a success message prefixed with "[OK]" in green to stdout.
print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
# print_error prints an error message prefixed with "[ERROR]" in red and resets terminal color.
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
# print_warn prints a warning message prefixed with [WARN] in yellow to stdout.
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# print_line prints a blue horizontal separator line to stdout.
print_line() {
    echo -e "${BLUE}===================================================================${NC}"
}

# HEADER
clear
print_line
echo -e "${CYAN}                    PORTAINER CE INSTALLER                         ${NC}"
print_line
echo ""

# check_dependencies verifies that `curl`, `docker`, and the Docker Compose plugin are present, prints which dependencies (if any) are missing, and returns a non‑zero status when requirements are unmet.
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

# check_docker_running checks whether the Docker daemon is running and accessible and prints remediation hints if it is not.
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

# check_existing_portainer checks for an existing Portainer compose file or container, prompts the user to remove it or cancel, and returns 0 if no conflicting deployment (or after removal) or 1 if the user cancels installation.
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
                if (cd /opt/portainer && docker compose -f "$compose_file" down) &>/dev/null; then
                    print_success "Existing deployment removed."
                    return 0
                else
                    print_error "Failed to remove existing deployment."
                    return 1
                fi
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
                if docker stop portainer &>/dev/null && docker rm portainer &>/dev/null; then
                    print_success "Existing container removed."
                    return 0
                else
                    print_error "Failed to remove existing container."
                    return 1
                fi
                ;;
            *)
                print_info "Installation cancelled."
                return 1
                ;;
        esac
    fi

    return 0
}

# verify_compose_integrity checks the downloaded compose file against the repo-controlled SHA-256.
verify_compose_integrity() {
    local compose_file="$1"
    local actual_sha

    print_info "Verifying compose file integrity..."
    actual_sha=$($SUDO sha256sum "$compose_file" | awk '{print $1}')
    if [[ "$actual_sha" != "$PORTAINER_COMPOSE_SHA256" ]]; then
        print_error "Compose file SHA-256 mismatch."
        print_warn "Expected: $PORTAINER_COMPOSE_SHA256"
        print_warn "Actual:   ${actual_sha:-<empty>}"
        return 1
    fi

    print_success "Compose file integrity verified."
    return 0
}

# pin_portainer_image rewrites floating Portainer image tags to the pinned digest.
pin_portainer_image() {
    local compose_file="$1"

    print_info "Pinning Portainer image to ${PORTAINER_IMAGE}..."
    if ! $SUDO grep -qE 'image:[[:space:]]*"?portainer/portainer-ce' "$compose_file"; then
        print_error "Compose file does not reference official Portainer CE image."
        return 1
    fi

    $SUDO sed -i -E 's#(image:[[:space:]]*"?)portainer/portainer-ce(:[A-Za-z0-9._-]+|@sha256:[a-fA-F0-9]+)?("?)#\1'"${PORTAINER_IMAGE}"'\3#' "$compose_file"
    if ! $SUDO grep -qF "image: ${PORTAINER_IMAGE}" "$compose_file" \
        && ! $SUDO grep -qF "image: \"${PORTAINER_IMAGE}\"" "$compose_file"; then
        print_error "Failed to pin Portainer image digest."
        return 1
    fi

    print_success "Portainer image pinned."
    return 0
}

# validate_compose_file validates a Docker Compose file for Portainer by checking that the file exists and is non-empty, contains a Portainer service and the official `portainer/portainer-ce` image reference, and has valid YAML syntax according to `docker compose config`; returns 0 on success and 1 on failure.
validate_compose_file() {
    local compose_file="$1"

    print_info "Validating compose file..."

    if [[ ! -f "$compose_file" ]]; then
        print_error "Compose file not found."
        return 1
    fi

    if [[ ! -s "$compose_file" ]]; then
        print_error "Compose file is empty."
        return 1
    fi

    # Check for expected Portainer service definition
    if ! $SUDO grep -q "portainer" "$compose_file"; then
        print_error "Compose file does not contain expected Portainer service."
        return 1
    fi

    # Check for pinned portainer image digest reference
    if ! $SUDO grep -qF "image: ${PORTAINER_IMAGE}" "$compose_file" \
        && ! $SUDO grep -qF "image: \"${PORTAINER_IMAGE}\"" "$compose_file"; then
        print_error "Compose file does not reference the pinned Portainer CE image digest."
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

# deploy_portainer Deploys Portainer CE (LTS) to /opt/portainer by creating the target directory (prompting to use sudo if required), downloading and validating the official compose file, and starting the stack with docker compose; returns 0 on success or 1 on failure.
deploy_portainer() {
    local compose_url="https://downloads.portainer.io/ce-lts/portainer-compose.yaml"
    local compose_dir="/opt/portainer"
    local compose_file="$compose_dir/portainer-compose.yaml"

    echo ""
    print_info "Deploying Portainer CE (LTS)..."

    if [[ ! -w "/opt" ]]; then
        if [[ "$EUID" -ne 0 ]]; then
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
    if ! $SUDO mkdir -p "$compose_dir"; then
        print_error "Failed to create directory."
        return 1
    fi

    print_info "Downloading Portainer compose file..."
    print_info "Source: $compose_url"

    local compose_tmp
    compose_tmp=$($SUDO mktemp "$compose_dir/portainer-compose.yaml.XXXXXX") || {
        print_error "Failed to create temporary compose file."
        return 1
    }

    if ! $SUDO curl -fsSL "$compose_url" -o "$compose_tmp"; then
        print_error "Failed to download compose file."
        $SUDO rm -f "$compose_tmp"
        return 1
    fi
    print_success "Compose file downloaded."

    # Authenticate the artifact before any parsing or privileged deployment.
    if ! verify_compose_integrity "$compose_tmp"; then
        $SUDO rm -f "$compose_tmp"
        return 1
    fi

    if ! pin_portainer_image "$compose_tmp"; then
        $SUDO rm -f "$compose_tmp"
        return 1
    fi

    # Validate the downloaded file before replacing any live compose file
    if ! validate_compose_file "$compose_tmp"; then
        print_error "Downloaded compose file failed validation."
        print_warn "The file may have been corrupted or the source may be compromised."
        $SUDO rm -f "$compose_tmp"
        return 1
    fi

    if ! $SUDO mv -f "$compose_tmp" "$compose_file"; then
        print_error "Failed to install validated compose file."
        $SUDO rm -f "$compose_tmp"
        return 1
    fi

    # mktemp defaults to 0600; allow non-sudo management commands to read the file.
    if ! $SUDO chmod a+r "$compose_file"; then
        print_error "Failed to set readable mode on compose file."
        return 1
    fi

    print_info "Starting Portainer containers..."
    echo ""

    if ! $SUDO docker compose -f "$compose_file" up -d; then
        print_error "Failed to deploy Portainer."
        return 1
    fi

    echo ""
    print_success "Portainer deployed successfully!"
    return 0
}

# show_access_info displays detected host IP, Portainer Web UI URLs (HTTP/HTTPS), notes about first-time admin and self-signed certificate, and common management commands.
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

# main orchestrates the Portainer CE installation workflow: it runs dependency and Docker checks, handles existing deployments, attempts deployment, and displays access information on success.
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