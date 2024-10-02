#!/bin/bash

# Function to check Linux distribution
check_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    else
        echo "Cannot determine Linux distribution."
        exit 1
    fi
}

# Function to create user
create_user() {
    if [ "$DISTRO" == "ubuntu" ] || [ "$DISTRO" == "debian" ]; then
        sudo adduser --disabled-password --gecos "" docker
    elif [ "$DISTRO" == "centos" ] || [ "$DISTRO" == "rhel" ]; then
        sudo adduser docker
    else
        echo "Unsupported Linux distribution."
        exit 1
    fi
}

# Function to set password for user
set_password() {
    echo "Please enter a password for the docker user:"
    sudo passwd docker
}

# Function to add user to docker group
add_to_docker_group() {
    if getent group docker > /dev/null 2>&1; then
        sudo usermod -aG docker docker
        echo "User docker added to docker group."
    else
        echo "Docker group does not exist. Please run the Docker install script first."
        exit 1
    fi
}

# Main script execution
check_distro
create_user
set_password
add_to_docker_group
