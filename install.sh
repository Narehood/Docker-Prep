#!/bin/bash

# Function to display the menu
show_menu() {
    clear
    echo -e "\033[0;32m=====================================\033[0m"
    echo -e "        \033[1;34mDocker Setup Menu 2.0.2\033[0m"
    echo -e "\033[0;32m=====================================\033[0m"
    echo -e "\033[1;32mSystem Information\033[0m"
    echo -e "-------------------------------------"
    echo -e "Linux Distribution: \033[1;33m$(grep '^NAME=' /etc/os-release | cut -d '"' -f2)\033[0m"
    echo -e "Kernel Version: \033[1;33m$(uname -r)\033[0m"
    echo -e "CPU Usage: \033[1;33m$(top -bn1 | grep 'Cpu(s)' | awk '{print 100 - $8"%"}')\033[0m"
    echo -e "Memory Usage: \033[1;33m$(free -m | awk 'NR==2{printf "%s/%sMB (%.2f%%)\n", $3,$2,$3*100/$2 }')\033[0m"
    echo -e "Disk Usage: \033[1;33m$(df -h | awk '$NF=="/"{printf "%d/%dGB (%s)\n", $3,$2,$5}')\033[0m"
    echo -e "\033[0;32m=====================================\033[0m"
    echo -e "\033[1;32mOptions\033[0m"
    echo -e "-------------------------------------"
    echo -e "\033[1;36m1.\033[0m Install Docker"
    echo -e "\033[1;36m2.\033[0m Add A User To The Docker Group"
    echo -e "\033[1;36m3.\033[0m Check for Updates"
    echo -e "\033[1;36m4.\033[0m Exit"
    echo -e "\033[0;32m=====================================\033[0m"
}

# Function to check for updates
check_for_updates() {
    echo "Checking for updates in VM-Setup repository..."
    git remote update
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse @{u})
    if [ "$LOCAL" = "$REMOTE" ]; then
        echo "VM-Setup is up to date."
    else
        echo "VM-Setup has updates available."
        read -p "Do you want to pull the latest changes? (y/n): " pull_choice
        pull_choice=${pull_choice:-n}  # Default to No
        if [ "$pull_choice" == "y" ]; then
            git pull
            echo "Repository updated successfully."
            bash install.sh
        else
            echo "Update aborted."
        fi
    fi
}

# Function to navigate to scripts and execute a script
execute_script() {
    local script_name=$1
    if [ -f "Scripts/$script_name" ]; then
        cd Scripts/
        bash "$script_name"
        cd ..
    else
        echo -e "\033[0;31mError: Script '$script_name' not found in 'Scripts/' directory.\033[0m"
    fi
}

# Main loop
while true; do
    show_menu
    read -p "Enter your choice [1-4]: " choice
    case $choice in
        1)
            echo "Installing Docker..."
            execute_script "serverSetup.sh"
            ;;
        2)
            echo "Adding User To The Docker Group..."
            execute_script "DockerGroup.sh"
            ;;
        3)
            echo "Checking for updates..."
            check_for_updates
            ;;
        4)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo -e "\033[0;31mInvalid option. Please choose a number between 1 and 4.\033[0m"
            ;;
    esac

    # Allow the user to return to the menu or exit
    if [ "$choice" -ne 4 ]; then
        read -p "Press [Enter] key to return to the menu or type 'exit' to quit: " exit_choice
        if [ "$exit_choice" == "exit" ]; then
            echo "Exiting..."
            exit 0
        fi
    fi
done
