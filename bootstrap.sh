#!/bin/bash
set -e

# Accept the repo URL as an argument, or fallback to a default
REPO_URL=${1:-"https://github.com/maskedpirate/ubuntu-dev-bootstrapping.git"}
REPO_DIR="/opt/kind-cluster-setup"

echo "Updating system and installing base prerequisites..."
sudo apt-get update
sudo apt-get install -y software-properties-common git curl

echo "Installing Ansible..."
sudo apt-add-repository -y ppa:ansible/ansible
sudo apt-get update
sudo apt-get install -y ansible

echo "Cloning repository..."
if [ -d "$REPO_DIR" ]; then
  # Sudo is required to delete the old root-owned folder in /opt/
  sudo rm -rf "$REPO_DIR"
fi

# Sudo is required to write to /opt/, which is protected by default
sudo git clone "$REPO_URL" "$REPO_DIR"

# Transfer ownership of the cloned folder back to your current user
sudo chown -R "$USER:$USER" "$REPO_DIR"

echo "Running Ansible Playbook..."
cd "$REPO_DIR"

# Run the playbook as root so Ansible doesn't prompt for a become password
# (The playbook will automatically detect your original user via $SUDO_USER)
sudo ansible-playbook -i localhost, -c local playbook.yml

echo "Bootstrap complete! You can now create your cluster with 'kind create cluster'."
