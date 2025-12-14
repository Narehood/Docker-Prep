#!/bin/bash
set -euo pipefail

# DIRECTORY ANCHOR
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
cd "$SCRIPT_DIR" || { echo "Failed to change directory to $SCRIPT_DIR"; exit 1; }

# VISUAL STYLING
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

UI_WIDTH=86
VERSION="2.2.0"

# Handle Ctrl+C gracefully
trap 'echo -e "\n${GREEN}Goodbye!${NC}"; exit 0' INT

print_centered() {
    local text="$1"
    local color="${2:-$NC}"
    local padding=$(( (UI_WIDTH - ${#text}) / 2 ))
    if [ "$padding" -lt 0 ]; then padding=0; fi
    printf "${color}%${padding}s%s${NC}\n" "" "$text"
}

print_line() {
    local char="${1:-=}"
    local color="${2:-$BLUE}"
    printf "${color}%${UI_WIDTH}s${NC}\n" "" | sed "s/ /${char}/g"
}

print_status() { echo -e "${CYAN}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

pause() {
    echo ""
    read -rp "Press [Enter] to return to the menu..."
}

truncate_string() {
    local str="$1"
    local max_len="$2"
    if [ ${#str} -gt "$max_len" ]; then
        echo "${str:0:$((max_len - 2))}.."
    else
        echo "$str"
    fi
}

show_header() {
    clear
    echo -e "${BLUE}███████╗██╗   ██╗███████╗████████╗███████╗███╗   ███╗    ███████╗███████╗████████╗██╗   ██╗██████╗ ${NC}"
    echo -e "${BLUE}██╔════╝╚██╗ ██╔╝██╔════╝╚══██╔══╝██╔════╝████╗ ████║    ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗${NC}"
    echo -e "${BLUE}███████╗ ╚████╔╝ ███████╗   ██║   █████╗  ██╔████╔██║    ███████╗█████╗     ██║   ██║   ██║██████╔╝${NC}"
    echo -e "${BLUE}╚════██║  ╚██╔╝  ╚════██║   ██║   ██╔══╝  ██║╚██╔╝██║    ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ ${NC}"
    echo -e "${BLUE}███████║   ██║   ███████║   ██║   ███████╗██║ ╚═╝ ██║    ███████║███████╗   ██║   ╚██████╔╝██║     ${NC}"
    echo -e "${BLUE}╚══════╝   ╚═╝   ╚══════╝   ╚═╝   ╚══════╝╚═╝     ╚═╝    ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     ${NC}"
    print_centered "VERSION $VERSION  |  DOCKER HOST PREPARATION" "$CYAN"
    print_line "=" "$BLUE"
}

show_stats() {
    # OS Detection
    local distro="Unknown"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$ID" = "alpine" ]; then
            distro="Alpine ${VERSION_ID:-}"
        else
            distro="${PRETTY_NAME:-$ID}"
        fi
    fi
    distro=$(truncate_string "$distro" 32)

    # Kernel
    local kernel
    kernel=$(truncate_string "$(uname -r)" 32)

    # Load average
    local cpu_load="N/A"
    if [ -f /proc/loadavg ]; then
        cpu_load=$(awk '{printf "%.2f (1m)", $1}' /proc/loadavg)
    fi

    # Memory
    local mem_usage="N/A"
    if [ -f /proc/meminfo ]; then
        local mem_total mem_avail mem_used mem_pct
        mem_total=$(awk '/^MemTotal:/ {print int($2/1024)}' /proc/meminfo)
        mem_avail=$(awk '/^MemAvailable:/ {print int($2/1024)}' /proc/meminfo)
        if [ -n "$mem_total" ] && [ -n "$mem_avail" ] && [ "$mem_total" -gt 0 ]; then
            mem_used=$((mem_total - mem_avail))
            mem_pct=$((mem_used * 100 / mem_total))
            mem_usage="${mem_used}/${mem_total}MB (${mem_pct}%)"
        fi
    fi

    # Disk usage
    local disk_usage="N/A"
    if command -v df >/dev/null 2>&1; then
        disk_usage=$(df -h / 2>/dev/null | awk 'NR==2{printf "%s/%s (%s)", $3,$2,$5}')
    fi

    # Network
    local hostname_str ip_addr="N/A" subnet="N/A" gateway="N/A"
    hostname_str=$(truncate_string "$(hostname)" 30)

    if command -v ip >/dev/null 2>&1; then
        local full_ip
        full_ip=$(ip -4 addr show scope global 2>/dev/null | awk '/inet / {print $2; exit}')
        if [ -n "$full_ip" ]; then
            ip_addr="${full_ip%%/*}"
            subnet="/${full_ip##*/}"
        fi
        gateway=$(ip route 2>/dev/null | awk '/default/ {print $3; exit}')
        gateway=$(truncate_string "${gateway:-N/A}" 20)
    fi

    # Docker status
    local docker_status="Not Installed"
    local docker_version=""
    if command -v docker >/dev/null 2>&1; then
        docker_version=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')
        if systemctl is-active --quiet docker 2>/dev/null; then
            docker_status="${GREEN}Running${NC} (v$docker_version)"
        else
            docker_status="${YELLOW}Stopped${NC} (v$docker_version)"
        fi
    else
        docker_status="${RED}Not Installed${NC}"
    fi

    # Docker Compose status
    local compose_status="Not Installed"
    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        local compose_ver
        compose_ver=$(docker compose version --short 2>/dev/null)
        compose_status="${GREEN}v$compose_ver${NC}"
    elif command -v docker-compose >/dev/null 2>&1; then
        local compose_ver
        compose_ver=$(docker-compose --version 2>/dev/null | awk '{print $4}' | tr -d ',')
        compose_status="${YELLOW}Legacy v$compose_ver${NC}"
    else
        compose_status="${RED}Not Installed${NC}"
    fi

    # DISPLAY GRID
    echo -e "${WHITE}SYSTEM INFORMATION${NC}"
    printf "  ${YELLOW}%-11s${NC} : %-30s ${YELLOW}%-11s${NC} : %s\n" "OS" "$distro" "IP Address" "$ip_addr"
    printf "  ${YELLOW}%-11s${NC} : %-30s ${YELLOW}%-11s${NC} : %s\n" "Kernel" "$kernel" "Subnet" "$subnet"
    printf "  ${YELLOW}%-11s${NC} : %-30s ${YELLOW}%-11s${NC} : %s\n" "Hostname" "$hostname_str" "Gateway" "$gateway"
    print_line "-" "$BLUE"
    printf "  ${YELLOW}%-11s${NC} : %-30s ${YELLOW}%-11s${NC} : %s\n" "Load Avg" "$cpu_load" "Memory" "$mem_usage"
    printf "  ${YELLOW}%-11s${NC} : %-30s\n" "Disk Usage" "$disk_usage"
    print_line "-" "$BLUE"
    printf "  ${YELLOW}%-11s${NC} : %-30b ${YELLOW}%-11s${NC} : %b\n" "Docker" "$docker_status" "Compose" "$compose_status"
    print_line "=" "$BLUE"
}

check_for_updates() {
    echo ""
    print_status "Checking for updates..."

    if ! command -v git >/dev/null 2>&1; then
        print_error "Git is not installed."
        sleep 2
        return 1
    fi

    if [ ! -d "$SCRIPT_DIR/.git" ]; then
        print_warn "Not a git repository. Skipping update check."
        sleep 2
        return 1
    fi

    if ! git fetch --quiet 2>/dev/null; then
        print_error "Failed to fetch from remote."
        sleep 2
        return 1
    fi

    local local_rev remote_rev
    local_rev=$(git rev-parse @ 2>/dev/null)

    if ! remote_rev=$(git rev-parse '@{u}' 2>/dev/null); then
        print_error "No upstream branch configured."
        sleep 2
        return 1
    fi

    if [ "$local_rev" = "$remote_rev" ]; then
        print_success "Menu is up to date."
        sleep 1
    else
        print_warn "New version available."
        read -rp "Download and apply updates? (y/N): " pull_choice
        pull_choice="${pull_choice:-n}"
        if [[ "$pull_choice" =~ ^[Yy]$ ]]; then
            if git pull --quiet; then
                print_success "Updated successfully. Restarting..."
                sleep 1
                exec bash "$SCRIPT_PATH"
            else
                print_error "Update failed. Try 'git pull' manually."
                sleep 2
            fi
        else
            print_status "Update skipped."
            sleep 1
        fi
    fi
}

execute_script() {
    local script_name="$1"
    local script_path="Scripts/$script_name"

    echo ""

    if [ ! -f "$script_path" ]; then
        print_error "Script '$script_name' not found in 'Scripts/' directory."
        pause
        return 1
    fi

    if [ ! -r "$script_path" ]; then
        print_error "Script '$script_name' not readable."
        pause
        return 1
    fi

    # Check if executable
    if [ ! -x "$script_path" ]; then
        print_warn "Script is not executable."
        read -rp "  Make it executable? (Y/n): " response
        response="${response:-y}"
        if [[ "$response" =~ ^[Yy]$ ]]; then
            chmod +x "$script_path" && print_success "Made executable." || {
                print_error "Failed to set executable."
                pause
                return 1
            }
        fi
    fi

    echo -e "${GREEN}>>> Executing: $script_name${NC}"
    print_line "-" "$BLUE"
    sleep 0.5

    # Execute in subshell to maintain directory context
    (
        cd Scripts || exit 1
        bash "$script_name"
    )
    local exit_code=$?

    echo ""
    print_line "-" "$BLUE"

    if [ $exit_code -ne 0 ]; then
        print_warn "Script exited with code: $exit_code"
    fi

    read -rp "Press [Enter] to return to menu or type 'exit': " next_action
    if [ "$next_action" = "exit" ]; then
        echo -e "\n${GREEN}Goodbye!${NC}"
        exit 0
    fi
}

install_docker() {
    echo ""
    print_status "Installing Docker Engine..."

    # Detect package manager and OS
    local pkg_manager=""
    local os_id=""

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        os_id="$ID"
    fi

    if command -v apt-get >/dev/null 2>&1; then
        pkg_manager="apt"
    elif command -v dnf >/dev/null 2>&1; then
        pkg_manager="dnf"
    elif command -v yum >/dev/null 2>&1; then
        pkg_manager="yum"
    elif command -v apk >/dev/null 2>&1; then
        pkg_manager="apk"
    else
        print_error "Unsupported package manager."
        pause
        return 1
    fi

    # Check if already installed
    if command -v docker >/dev/null 2>&1; then
        local current_ver
        current_ver=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')
        print_warn "Docker is already installed (v$current_ver)."
        read -rp "  Reinstall/update? (y/N): " reinstall
        reinstall="${reinstall:-n}"
        if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
            print_status "Skipping installation."
            pause
            return 0
        fi
    fi

    # Check for root
    if [ "$EUID" -ne 0 ]; then
        print_warn "This operation requires root privileges."
        read -rp "  Run with sudo? (Y/n): " use_sudo
        use_sudo="${use_sudo:-y}"
        if [[ ! "$use_sudo" =~ ^[Yy]$ ]]; then
            print_status "Cancelled."
            pause
            return 0
        fi
        local SUDO="sudo"
    else
        local SUDO=""
    fi

    print_status "Using official Docker installation script..."
    print_line "-" "$BLUE"

    # Use Docker's convenience script
    if curl -fsSL https://get.docker.com -o /tmp/get-docker.sh; then
        $SUDO sh /tmp/get-docker.sh
        local exit_code=$?
        rm -f /tmp/get-docker.sh

        if [ $exit_code -eq 0 ]; then
            print_success "Docker installed successfully!"

            # Enable and start Docker
            if command -v systemctl >/dev/null 2>&1; then
                $SUDO systemctl enable docker 2>/dev/null || true
                $SUDO systemctl start docker 2>/dev/null || true
                print_success "Docker service enabled and started."
            fi
        else
            print_error "Docker installation failed."
        fi
    else
        print_error "Failed to download Docker installation script."
    fi

    pause
}

add_user_to_docker_group() {
    echo ""

    if ! command -v docker >/dev/null 2>&1; then
        print_error "Docker is not installed. Install Docker first."
        pause
        return 1
    fi

    # Get current user
    local current_user="${SUDO_USER:-$USER}"
    print_status "Current user: $current_user"

    # Check if user is already in docker group
    if groups "$current_user" 2>/dev/null | grep -qw docker; then
        print_success "User '$current_user' is already in the docker group."
        pause
        return 0
    fi

    read -rp "  Add '$current_user' to docker group? (Y/n): " confirm
    confirm="${confirm:-y}"
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_status "Cancelled."
        pause
        return 0
    fi

    # Check for root
    if [ "$EUID" -ne 0 ]; then
        if ! command -v sudo >/dev/null 2>&1; then
            print_error "sudo is required but not installed."
            pause
            return 1
        fi
        local SUDO="sudo"
    else
        local SUDO=""
    fi

    # Ensure docker group exists
    if ! getent group docker >/dev/null 2>&1; then
        print_status "Creating docker group..."
        $SUDO groupadd docker
    fi

    # Add user to group
    if $SUDO usermod -aG docker "$current_user"; then
        print_success "User '$current_user' added to docker group."
        echo ""
        print_warn "You must log out and back in for this to take effect."
        print_warn "Or run: newgrp docker"
    else
        print_error "Failed to add user to docker group."
    fi

    pause
}

show_docker_info() {
    echo ""
    print_line "=" "$BLUE"
    print_centered "DOCKER SYSTEM INFORMATION" "$WHITE"
    print_line "=" "$BLUE"
    echo ""

    if ! command -v docker >/dev/null 2>&1; then
        print_error "Docker is not installed."
        pause
        return 1
    fi

    # Check if we can talk to Docker daemon
    if ! docker info >/dev/null 2>&1; then
        print_warn "Cannot connect to Docker daemon."
        print_status "Try running with sudo or add user to docker group."
        pause
        return 1
    fi

    # Docker version info
    echo -e "${WHITE}Version Information:${NC}"
    docker version --format '  Client: {{.Client.Version}}
  Server: {{.Server.Version}}
  API:    {{.Client.APIVersion}}' 2>/dev/null || print_warn "Could not get version info"
    echo ""

    # System info
    echo -e "${WHITE}System Status:${NC}"
    local containers_running containers_stopped images
    containers_running=$(docker ps -q 2>/dev/null | wc -l)
    containers_stopped=$(docker ps -aq 2>/dev/null | wc -l)
    containers_stopped=$((containers_stopped - containers_running))
    images=$(docker images -q 2>/dev/null | wc -l)

    printf "  ${YELLOW}%-20s${NC} : %s\n" "Running Containers" "$containers_running"
    printf "  ${YELLOW}%-20s${NC} : %s\n" "Stopped Containers" "$containers_stopped"
    printf "  ${YELLOW}%-20s${NC} : %s\n" "Images" "$images"
    echo ""

    # Disk usage
    echo -e "${WHITE}Disk Usage:${NC}"
    docker system df 2>/dev/null | tail -n +2 | while read -r line; do
        echo "  $line"
    done

    echo ""
    print_line "=" "$BLUE"
    pause
}

# Menu options
declare -A MENU_OPTIONS=(
    [1]="install_docker:Install Docker Engine"
    [2]="add_user_to_docker_group:Add User to Docker Group"
    [3]="show_docker_info:Docker System Info"
    [4]="check_for_updates:Check for Updates"
)

show_menu() {
    echo -e "${WHITE}DOCKER CONFIGURATION${NC}"
    printf "  ${CYAN}1.${NC} %-43s ${CYAN}3.${NC} %s\n" "Install Docker Engine" "Docker System Info"
    printf "  ${CYAN}2.${NC} %-43s ${CYAN}4.${NC} %s\n" "Add User to Docker Group" "Check for Updates"
    echo ""
    printf "  ${CYAN}0.${NC} ${RED}%s${NC}\n" "Return to Main Menu"
    echo ""
    print_line "-" "$BLUE"
}

# MAIN LOOP
while true; do
    show_header
    show_stats
    show_menu

    read -rp "  Enter selection [0-4]: " choice

    case "$choice" in
        1) install_docker ;;
        2) add_user_to_docker_group ;;
        3) show_docker_info ;;
        4) check_for_updates ;;
        0|q|exit)
            echo -e "\n${GREEN}Returning to Main Menu...${NC}"
            exit 0
            ;;
        "")
            ;;
        *)
            print_error "Invalid option: $choice"
            sleep 1
            ;;
    esac
done
