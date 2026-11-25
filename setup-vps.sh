#!/usr/bin/env bash
# One-time VPS bootstrap (Ubuntu 22.04/24.04). Run as root:  bash setup-vps.sh <username>
set -euo pipefail
USER_NAME=${1:?usage: setup-vps.sh <username>}

apt-get update && apt-get -y upgrade
apt-get install -y ca-certificates curl git ufw fail2ban unattended-upgrades

# Non-root sudo user with your SSH key
id "$USER_NAME" &>/dev/null || adduser --disabled-password --gecos "" "$USER_NAME"
usermod -aG sudo "$USER_NAME"
mkdir -p /home/$USER_NAME/.ssh
cp -n /root/.ssh/authorized_keys /home/$USER_NAME/.ssh/ 2>/dev/null || true
chown -R $USER_NAME:$USER_NAME /home/$USER_NAME/.ssh && chmod 700 /home/$USER_NAME/.ssh

# SSH: keys only, no root login
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/; s/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart ssh || systemctl restart sshd

# Firewall
ufw default deny incoming
ufw allow OpenSSH
ufw allow 80,443/tcp
ufw allow 1883/tcp
ufw --force enable

# 2 GB swap (JVM + 4 Next servers)
if ! swapon --show | grep -q /swapfile; then
  fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# Docker
curl -fsSL https://get.docker.com | sh
usermod -aG docker "$USER_NAME"

mkdir -p /opt/cuetrack && chown $USER_NAME:$USER_NAME /opt/cuetrack
echo "Done. Log in as $USER_NAME (verify SSH key works BEFORE closing this session)."
