#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <PUBLIC_IP>" >&2
    exit 1
fi

PUBLIC_IP="$1"
BASE_DIR="$(cd "$(dirname "$0")"/.. && pwd)"
COMPOSE_DIR="$BASE_DIR/compose"

# System prep (idempotent where possible)
echo "Updating system and installing dependencies..."

if ! dpkg -l | grep -q docker-ce; then
    sudo apt-get update -y
    sudo apt-get install -y ca-certificates curl git jq
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release; echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
    echo "Docker already installed, skipping."
fi

# Start Docker if not running
if ! sudo systemctl is-active --quiet docker; then
    sudo systemctl start docker
    sudo systemctl enable docker
fi

# Kernel/network tuning
if [ ! -f /etc/sysctl.d/99-targetfarm.conf ]; then
    sudo tee /etc/sysctl.d/99-targetfarm.conf > /dev/null <<'SYS'
net.core.somaxconn = 4096
net.ipv4.ip_local_port_range = 1024 65000
net.core.netdev_max_backlog = 250000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
fs.file-max = 2097152
SYS
    sudo sysctl --system
    echo "Applied sysctl tuning."
else
    echo "Sysctl config already exists, skipping."
fi

# ulimit
if ! grep -q "nofile 1048576" /etc/security/limits.conf; then
    echo '* soft nofile 1048576' | sudo tee -a /etc/security/limits.conf
    echo '* hard nofile 1048576' | sudo tee -a /etc/security/limits.conf
    echo "Updated limits.conf."
else
    echo "Limits already set, skipping."
fi

# Setup dirs (should exist from git clone, but ensure)
mkdir -p "$COMPOSE_DIR"

# Pull images and start compose
cd "$COMPOSE_DIR"
docker compose pull
docker compose up -d
echo "Docker Compose started."

# Generate targets
cd "$BASE_DIR"
if [ ! -f targets.txt ] || [ ! -s targets.txt ]; then
    python3 scripts/generate_targets.py "$PUBLIC_IP" > targets.txt
    echo "Generated targets.txt with $(wc -l < targets.txt) targets."
else
    echo "targets.txt already exists, skipping generation."
fi

# Smoke tests
echo "Running smoke tests..."
IP="$PUBLIC_IP"
for test in "ok-001.$IP.sslip.io/get" "redirect-001.$IP.sslip.io/" "rl-001.$IP.sslip.io/" "delay1s-001.$IP.sslip.io/" "big-001.$IP.sslip.io/bytes/1048576" "waf-001.$IP.sslip.io/?q=union%20select"; do
    if curl -s -o /dev/null -w "%{http_code}" "http://$test" | grep -q "2.."; then
        echo "PASS: $test"
    else
        echo "FAIL: $test"
    fi
done

echo "Setup complete!"