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
[ -s /root/.ssh/authorized_keys ] && cat /root/.ssh/authorized_keys >> /home/$USER_NAME/.ssh/authorized_keys
sort -u -o /home/$USER_NAME/.ssh/authorized_keys /home/$USER_NAME/.ssh/authorized_keys 2>/dev/null || true
chown -R $USER_NAME:$USER_NAME /home/$USER_NAME/.ssh && chmod 700 /home/$USER_NAME/.ssh
chmod 600 /home/$USER_NAME/.ssh/authorized_keys 2>/dev/null || true

# SSH: keys only, no root login - but ONLY if a key is installed, otherwise you'd be locked out
if [ -s /home/$USER_NAME/.ssh/authorized_keys ]; then
  # cloud images re-enable passwords in sshd_config.d/*.conf, which overrides sshd_config
  for f in /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf; do
    [ -f "$f" ] && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/; s/^#\?PermitRootLogin.*/PermitRootLogin no/' "$f"
  done
  sshd -t && { systemctl restart ssh || systemctl restart sshd; }
else
  echo "WARNING: no SSH key found in /root/.ssh/authorized_keys - password login left ENABLED."
  echo "         Run 'ssh-copy-id $USER_NAME@<server-ip>' from your PC, then re-run this script."
  echo "         Set a password for sudo now:  passwd $USER_NAME"
fi

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
