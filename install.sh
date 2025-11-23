#!/bin/bash

# --- 1. DIRECTORY ANCHOR ---
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
cd "$SCRIPT_DIR" || { echo "Failed to change directory to $SCRIPT_DIR"; exit 1; }

# --- 2. VISUAL STYLING ---
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Standard Width for the UI
UI_WIDTH=66

# Function to print a centered line
print_centered() {
    local text="$1"
    local color="${2:-$NC}"
    local width=$UI_WIDTH
    local padding=$(( (width - ${#text}) / 2 ))
    printf "${color}%${padding}s%s${NC}\n" "" "$text"
}

# Function to print a separator line
print_line() {
    local char="${1:-=}"
    local color="${2:-$BLUE}"
    local line=""
    for ((i=0; i<UI_WIDTH; i++)); do line="${line}${char}"; done
    echo -e "${color}${line}${NC}"
}

pause() {
    echo ""
    read -p "Press [Enter] to return to the menu..."
}

show_header() {
    clear
    echo -e "${BLUE}██╗   ██╗███╗   ███╗    ███████╗███████╗████████╗██╗   ██╗██████╗ ${NC}"
    echo -e "${BLUE}██║   ██║████╗ ████║    ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗${NC}"
    echo -e "${BLUE}██║   ██║██╔████╔██║    ███████╗█████╗     ██║   ██║   ██║██████╔╝${NC}"
    echo -e "${BLUE}╚██╗ ██╔╝██║╚██╔╝██║    ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ ${NC}"
    echo -e "${BLUE} ╚████╔╝ ██║ ╚═╝ ██║    ███████║███████╗   ██║   ╚██████╔╝██║     ${NC}"
    echo -e "${BLUE}  ╚═══╝  ╚═╝     ╚═╝    ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     ${NC}"
    print_centered "VERSION 2.1.0  |  DOCKER PREP" "$CYAN"
    print_line "=" "$BLUE"
}

show_stats() {
    # --- DATA COLLECTION ---
    
    # OS Detection
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$ID" = "alpine" ]; then DISTRO="Alpine $VERSION_ID"; else DISTRO="${PRETTY_NAME:-$ID}"; fi
    else
        DISTRO="Unknown"
    fi
    if [ ${#DISTRO} -gt 22 ]; then DISTRO="${DISTRO:0:20}.."; fi

    # Kernel
    KERNEL=$(uname -r)
    if [ ${#KERNEL} -gt 22 ]; then KERNEL="${KERNEL:0:20}.."; fi

    # Resources
    CPU_LOAD=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf "%.1f%%", usage}')
    MEM_USAGE=$(free -m | awk 'NR==2{printf "%s/%sMB (%.0f%%)", $3,$2,$3*100/$2 }')
    DISK_USAGE=$(df -h / | awk '$NF=="/"{printf "%s/%s (%s)", $3,$2,$5}')
    
    # Network
    HOSTNAME=$(hostname)
    if [ ${#HOSTNAME} -gt 20 ]; then HOSTNAME="${HOSTNAME:0:18}.."; fi

    IP_ADDR="Unknown"
    SUBNET="Unknown"
    
    if command -v ip &> /dev/null; then
        FULL_IP=$(ip -4 addr show scope global | grep inet | awk '{print $2}' | head -n 1)
        if [ -n "$FULL_IP" ]; then
            IP_ADDR=$(echo "$FULL_IP" | cut -d/ -f1)
            CIDR=$(echo "$FULL_IP" | cut -d/ -f2)
            SUBNET="/$CIDR"
        fi
    fi
    
    GATEWAY=$(ip route | grep default | awk '{print $3}' | head -n 1)
    if [ ${#GATEWAY} -gt 15 ]; then GATEWAY="${GATEWAY:0:13}.."; fi

    # --- DISPLAY GRID ---
    echo -e "${WHITE}SYSTEM INFORMATION${NC}"
    
    printf "  ${YELLOW}%-11s${NC} : %-20s ${YELLOW}%-11s${NC} : %s\n" "OS" "$DISTRO" "IP Address" "${IP_ADDR:-N/A}"
    printf "  ${YELLOW}%-11s${NC} : %-20s ${YELLOW}%-11s${NC} : %s\n" "Kernel" "$KERNEL" "Subnet" "${SUBNET:-N/A}"
    printf "  ${YELLOW}%-11s${NC} : %-20s ${YELLOW}%-11s${NC} : %s\n" "Hostname" "$HOSTNAME" "Gateway" "${GATEWAY:-N/A}"
    print_line "-" "$BLUE"
    printf "  ${YELLOW}%-11s${NC} : %-20s ${YELLOW}%-11s${NC} : %s\n" "CPU Usage" "$CPU_LOAD" "Memory" "$MEM_USAGE"
    printf "  ${YELLOW}%-11s${NC} : %-20s\n" "Disk Usage" "$DISK_USAGE" 
    print_line "=" "$BLUE"
}

# Function to check for updates
check_for_updates() {
    echo -e "\n${CYAN}[INFO]${NC} Checking for updates..."
    git fetch
    LOCAL=$(git rev-parse @)
    if ! REMOTE=$(git rev-parse @{u} 2>/dev/null); then
        echo -e "${RED}[ERROR]${NC} No upstream branch configured."
        pause
        return
    fi

    if [ "$LOCAL" = "$REMOTE" ]; then
        echo -e "${GREEN}[OK]${NC} Menu is up to date."
        sleep 1
    else
        echo -e "${YELLOW}[UPDATE]${NC} New version available."
        read -p "Download and apply updates? (y/n): " pull_choice
        pull_choice=${pull_choice:-n}
        if [[ "$pull_choice" =~ ^[Yy]$ ]]; then
            git pull
            echo -e "${GREEN}[SUCCESS]${NC} Updated successfully. Restarting..."
            sleep 1
            exec bash "$SCRIPT_PATH" "$@"
        else
            echo "Update skipped."
        fi
    fi
}

# Function to navigate to scripts and execute a script
execute_script() {
    local script_name=$1
    local script_path="Scripts/$script_name"

    if [ -f "$script_path" ]; then
        echo -e "\n${GREEN}>>> Executing: $script_name ${NC}"
        sleep 0.5
        # Execute inside a subshell or pushd/popd to ensure we stay in root dir
        (
            cd Scripts || exit
            bash "$script_name"
        )
        
        # Return logic
        echo ""
        print_line "-" "$BLUE"
        read -p "Press [Enter] to return to menu or type 'exit': " next_action
        if [ "$next_action" = "exit" ]; then
            echo -e "\n${GREEN}Goodbye!${NC}"
            exit 0
        fi
    else
        echo -e "\n${RED}[ERROR]${NC} Script '$script_name' not found in 'Scripts/' directory."
        pause
    fi
}

# --- MAIN LOOP ---
while true; do
    show_header
    show_stats
    
    echo -e "${WHITE}DOCKER CONFIGURATION${NC}"
    
    printf "  ${CYAN}1.${NC} %-33s ${CYAN}3.${NC} %s\n" "Install Docker Engine" "Check for Updates"
    printf "  ${CYAN}2.${NC} %-33s ${CYAN}4.${NC} ${RED}%s${NC}\n" "Add User to Docker Group" "Exit"
    
    echo ""
    print_line "-" "$BLUE"
    read -p "  Enter selection [1-4]: " choice

    case $choice in
        1) execute_script "serverSetup.sh" ;;
        2) execute_script "DockerGroup.sh" ;;
        3) check_for_updates ;;
        4) 
            echo -e "\n${GREEN}Goodbye!${NC}"
            exit 0 
            ;;
        *) 
            echo -e "\n${RED}Invalid option.${NC}"
            sleep 1
            ;;
    esac
done
