#!/bin/bash
set -e

# Accept the repo URL as an argument, or fallback to a default
REPO_URL=${1:-"https://github.com/maskedpirate/ubuntu-dev-bootstrapping.git"}
REPO_DIR="/opt/kind-cluster-setup"

echo "Updating system and installing base prerequisites..."
sudo sudo apt-get update
apt-get install -y software-properties-common git curl

echo "Installing Ansible..."
sudo apt-add-repository -y ppa:ansible/ansible
sudo apt-get update
sudo apt-get install -y ansible

echo "Cloning repository..."
if [ -d "$REPO_DIR" ]; then
  rm -rf "$REPO_DIR"
fi
git clone "$REPO_URL" "$REPO_DIR"

echo "Running Ansible Playbook..."
cd "$REPO_DIR"

# Run the playbook locally
ansible-playbook -i localhost, -c local playbook.yml

echo "Bootstrap complete! You can now create your cluster with 'kind create cluster'."
