#!/bin/bash

# Prompt the user for the account name
read -p "Enter the username you want to add to the docker group: " username

# Check if the user exists
if id "$username" &>/dev/null; then
    # Add the user to the docker group
    sudo usermod -aG docker "$username"
    echo "User $username has been added to the docker group."
else
    echo "User $username does not exist."
fi
