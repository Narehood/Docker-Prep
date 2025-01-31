#!/bin/bash

# Function to display the menu
show_menu() {
    clear
    echo -e "====================================="
    echo -e "          \e[1;34mVM Setup Menu 1.2.0\e[0m"
    echo -e "====================================="
    echo -e "\e[1;32mSystem Information\e[0m"
    echo -e "-------------------------------------"
    echo -e "Linux Distribution: \e[1;33m$(lsb_release -d | cut -f2)\e[0m"
    echo -e "Kernel Version: \e[1;33m$(uname -r)\e[0m"
    echo -e "CPU Usage: \e[1;33m$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')\e[0m"
    echo -e "Memory Usage: \e[1;33m$(free -m | awk 'NR==2{printf "Memory Usage: %s/%sMB (%.2f%%)\n", $3,$2,$3*100/$2 }')\e[0m"
    echo -e "Disk Usage: \e[1;33m$(df -h | awk '$NF=="/"{printf "Disk Usage: %d/%dGB (%s)\n", $3,$2,$5}')\e[0m"
    echo -e "====================================="
    echo -e "\e[1;32mOptions\e[0m"
    echo -e "-------------------------------------"
    echo -e "\e[1;36m1.\e[0m Install Docker"
    echo -e "\e[1;36m2.\e[0m Add A User To The Docker Group"
    echo -e "\e[1;36m3.\e[0m Check for Updates"
    echo -e "\e[1;36m4.\e[0m Exit"
    echo -e "====================================="
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
        if [ "$pull_choice" = "y" ]; then
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
    cd Scripts/
    bash "$script_name"
}

# Main loop
while true; do
    show_menu
    read -p "Enter your choice [1-4]: " choice
    case $choice in
        1)
            echo "Installing Docker"
            execute_script "serverSetup.sh"
            ;;
        2)
            echo "Adding User To The Docker Group"
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
            echo "Invalid option. Please choose a number between 1 and 4."
            ;;
    esac
    if [ "$choice" -ne 4 ]; then
        read -p "Press [Enter] key to return to menu or type 'exit' to exit: " next_action
        if [ "$next_action" = "exit" ]; then
            exit 0
        fi
    fi
done
