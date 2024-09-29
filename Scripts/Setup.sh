#!/bin/bash

# Function to install Docker using apt
install_docker_apt() {
    sudo apt update && sudo apt upgrade
    sudo snap install docker
    sudo addgroup --system docker
    sudo adduser $USER docker
    sudo snap disable docker
    sudo snap enable docker
    docker --version
}

# Function to install Docker using dnf
install_docker_dnf() {
    sudo dnf -y install dnf-plugins-core
    sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl start docker
    sudo systemctl enable docker
}

# Function to install Docker using yum
install_docker_yum() {
    sudo yum install -y yum-utils
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl start docker
    sudo systemctl enable docker
}

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Installing Docker..."
    # Detect the package manager and install Docker
    if command -v apt-get &> /dev/null; then
        install_docker_apt
    elif command -v dnf &> /dev/null; then
        install_docker_dnf
    elif command -v yum &> /dev/null; then
        install_docker_yum
    else
        echo "Unsupported package manager. Please install Docker manually."
        exit 1
    fi
else
    echo "Docker is already installed. Skipping Docker installation."
fi

# Install Portainer
sudo docker volume create portainer_data
sudo docker run -d -p 9000:9000 --name=portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce

# Install Watchtower to automatically update Portainer
sudo docker run -d --name watchtower --restart=always -v /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower portainer --cleanup

# Get the IP address of the machine
IP_ADDRESS=$(hostname -I | awk '{print $1}')

echo "Docker and Portainer installation complete. The 'docker' user has been created and added to the 'docker' group."
echo "You can access Portainer at http://$IP_ADDRESS:9000 or your domain if configured."
echo "Watchtower has been installed to automatically update Portainer."
echo "You should add the docker group to a non-root user to use for Docker commands"
