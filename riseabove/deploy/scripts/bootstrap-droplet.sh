#!/usr/bin/env bash
# One-time setup for a fresh Ubuntu 24.04 droplet: Docker, host firewall, automatic security
# updates, and the nightly MySQL backup. Run as root from the deploy/ directory's parent checkout.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root." >&2
  exit 1
fi

DEPLOY_DIR="$(cd "$(dirname "$0")/.." && pwd)"

apt-get update
apt-get install -y ca-certificates curl gnupg ufw unattended-upgrades

# Docker Engine from Docker's apt repository (https://docs.docker.com/engine/install/ubuntu/).
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable --now docker

# Host firewall. Also add a DigitalOcean Cloud Firewall with the same rules (and SSH limited to
# known IPs): Docker-published ports bypass ufw, so the cloud firewall is the one that counts.
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 443/udp
ufw --force enable

dpkg-reconfigure -f noninteractive unattended-upgrades

# Nightly database backup at 02:30 server time.
cat > /etc/cron.d/riseabove-mdm-backup <<EOF
30 2 * * * root ${DEPLOY_DIR}/scripts/backup-mysql.sh >> /var/log/riseabove-mdm-backup.log 2>&1
EOF
chmod 0644 /etc/cron.d/riseabove-mdm-backup

echo "Done. Next: scripts/init-env.sh, then 'docker compose up -d' in ${DEPLOY_DIR}."
