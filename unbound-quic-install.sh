#!/usr/bin/env bash
# Install Unbound 1.22.0 with support for DNS over QUIC

set -o errexit
set -o pipefail

if [ "$EUID" -ne 0 ]
  then echo "Please run the script as root or invoke via sudo."
  exit
fi

REPO_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

rm -f run.log && touch run.log

# Install extra dependencies
sudo apt install python3 libpython3-dev | tee -a run.log

# Unzip unbound.tar and move to sbin
echo "Extracting Unbound"
tar xzf unbound-quic-1.22.0.tar.gz | tee -a run.log
sudo cp -r "$REPO_PATH/unbound-quic-1.22.0/local/." /usr/local/ | tee -a run.log
sudo cp -r "$REPO_PATH/unbound-quic-1.22.0/sbin/." /usr/sbin/ | tee -a run.log

# Generate user for unbound.service
echo "Generating new user (unbound)"
sudo useradd -M --system --shell /usr/sbin/nologin --user-group unbound | tee -a run.log

# Create app directories
echo "Creating app directories and configuring ownership"
sudo mkdir -p /var/lib/unbound/certs /var/log/unbound /etc/unbound | tee -a run.log
sudo cp "$REPO_PATH/config/unbound.conf" /etc/unbond.conf

# Generate root hints
wget https://www.internic.net/domain/named.root -qO- | sudo tee /var/lib/unbound/root.hints

# Set permissions
sudo chown -R unbound:unbound /var/lib/unbound /var/log/unbound /etc/unbound | tee -a run.log
sudo chmod -R 755 /var/lib/unbound /var/log/unbound /etc/unbound | tee -a run.log

# Run unbound utils
sudo apt install unbound-anchor | tee -a run.log
sudo -u unbound /usr/sbin/unbound-anchor -a /var/lib/unbound/root.key || echo "Unbound-anchor may have failed to update the root.key used to verify DNSSEC signatures." | tee -a run.log
sudo -u unbound /usr/sbin/unbound-control-setup | tee -a run.log

# Configure systemd
sudo cp "$REPO_PATH/system/unbound.service" /etc/systemd/system/unbound.service | tee -a run.log
sudo systemctl daemon-reload

# Configure apparmor
if sudo apparmor_status | grep -q "module is loaded"; then
  sudo cp "$REPO_PATH/apparmor.d/usr.sbin.unbound" /etc/apparmor.d/usr.sbin.unbound | tee -a run.log
  sudo touch /etc/apparmor.d/local/usr.sbin.unbound
  sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.unbound | tee -a run.log
fi

# Enable unbound
systemctl enable unbound | tee -a run.log
systemctl restart unbound | tee -a run.log
systemctl status unbound | tee -a run.log
echo "Unbound installed."
