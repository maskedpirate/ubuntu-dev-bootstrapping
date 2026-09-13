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

echo "Preparing $REPO_DIR..."
# /opt is root-owned by default, so creating the directory and handing it to
# the current user is the only sudo needed for the repo itself. Everything
# after this (the clone, and the Ansible run) happens as you.
sudo mkdir -p "$REPO_DIR"
sudo chown "$USER:$USER" "$REPO_DIR"

echo "Cloning repository..."
# Clear any existing contents rather than removing the directory entry
# itself, since deleting/recreating it under /opt still requires root.
find "$REPO_DIR" -mindepth 1 -delete
git clone "$REPO_URL" "$REPO_DIR"

echo "Running Ansible Playbook..."
cd "$REPO_DIR"

# Run as your own user. Ansible prompts once for your sudo password (-K)
# and reuses it only for the tasks that actually need to become root.
ansible-playbook -i localhost, -c local playbook.yml -K

echo "Bootstrap complete! You can now create your cluster with 'kind create cluster'."
