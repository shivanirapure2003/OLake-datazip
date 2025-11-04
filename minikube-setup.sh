#!/usr/bin/env bash
set -eux

# This script installs Docker, kubectl, minikube, and Helm on Ubuntu 22.04
# Runs as root via sudo in the Terraform remote-exec provisioner.

# Update & install basic deps
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release conntrack

# Install Docker (using official repo)
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo     "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu     $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io
  usermod -aG docker ubuntu || true
fi

# Install kubectl
if ! command -v kubectl >/dev/null 2>&1; then
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
fi

# Install minikube
if ! command -v minikube >/dev/null 2>&1; then
  curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  install minikube-linux-amd64 /usr/local/bin/minikube
fi

# Install Helm
if ! command -v helm >/dev/null 2>&1; then
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Allow ubuntu user to run docker without sudo in this session
newgrp docker <<'NG'
# Start minikube with docker driver
minikube start --cpus=3 --memory=6144 --driver=docker --kubernetes-version=v1.27.6

# Enable addons
minikube addons enable ingress
minikube addons enable storage-provisioner

# Wait for kube system pods
kubectl wait --for=condition=ready pods -n kube-system --all --timeout=300s || true

# Prepare values.yaml: replace placeholder VM_IP with instance metadata public IP
VM_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || true)
if [ -n "$VM_IP" ]; then
  sed -i "s/{{VM_IP}}/${VM_IP}/g" /home/ubuntu/values.yaml || true
fi

# Add olake helm repo and deploy
helm repo add olake https://datazip-inc.github.io/olake-helm || true
helm repo update

# Create namespace and install (wait for completion)
helm upgrade --install olake olake/olake -n olake --create-namespace -f /home/ubuntu/values.yaml --wait --timeout 10m || true

# Print status for verification
kubectl get pods -A
kubectl get svc -n olake
NG

# End of script
