#!/usr/bin/env bash
# Install Unbound 1.22.0 with support for DNS over QUIC

set -o errexit
set -o pipefail

if [ "$EUID" -ne 0 ]
  then echo "Please run the script as root or invoke via sudo."
  exit
fi

rm -f run.log && touch run.log

# Install extra dependencies
sudo apt install python3 

# Unzip unbound.tar and move to sbin
echo "Extracting Unbound"
tar xzf unbound-quic-1.22.0.tar.gz | tee -a run.log
cd unbound-quic-1.22.0
sudo cp -r local/ /usr/local/ | tee -a run.log
sudo cp -r sbin /usr/sbin/ | tee -a run.log

# Generate user for unbound.service
echo "Generating new user (unbound)"
sudo groupadd --system unbound | tee -a run.log
sudo useradd --system --home /var/lib/unbound --shell /usr/sbin/nologin --ingroup unbound unbound | tee -a run.log

# Create app directories
echo "Creating app directories and configuring ownership"
sudo mkdir -p /var/lib/unbound/certs /var/log/unbound /etc/unbound | tee -a run.log
sudo cp config/unbound.conf /etc/unbond.conf

# Generate root hints
wget https://www.internic.net/domain/named.root -qO- | sudo tee /var/lib/unbound/root.hints

# Set permissions
sudo chown -R unbound:unbound /var/lib/unbound /var/log/unbound /etc/unbound | tee -a run.log
sudo chmod -R 755 /var/lib/unbound /var/log/unbound /etc/unbound | tee -a run.log

# Run unbound utils
sudo -u unbound /usr/local/sbin/unbound-anchor || echo "Unbound-anchor may have failed to update the root.key used to verify DNSSEC signatures." | tee -a run.log
sudo -u unbound /usr/local/sbin/unbound-control-setup | tee -a run.log

# Configure systemd
sudo cp system/unbound.service /etc/systemd/system/unbound.service | tee -a run.log
sudo systemctl daemon-reload

# Configure apparmor
if sudo apparmor_status | grep -q "module is loaded"; then
  sudo cp apparmor.d/usr.sbin.unbound /etc/apparmor.d/usr.sbin.unbound | tee -a run.log
  sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.unbound | tee -a run.log
fi

# Enable unbound
systemctl enable unbound | tee -a run.log
systemctl restart unbound | tee -a run.log
systemctl status unbound | tee -a run.log
echo "Unbound installed."
