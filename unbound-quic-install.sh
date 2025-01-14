#!/usr/bin/env bash
# Install Unbound 1.22.0 with support for DNS over QUIC

set -o errexit
set -o pipefail

if [ "$EUID" -ne 0 ]
  then echo "Please run the script as root or invoke via sudo."
  exit
fi

REPO_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
UNBOUND_PATH=/etc/unbound
LIB_PATH=/var/lib/unbound
LOG_PATH=/var/log/unbound
CERT_PATH="$LIB_PATH/certs"

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
sudo mkdir -p $CERT_PATH $LOG_PATH $UNBOUND_PATH | tee -a run.log
sudo cp "$REPO_PATH/config/unbound.conf" "$UNBOUND_PATH/unbound.conf"

# Generate root hints
echo "Downloading internic root.hints to local cache"
wget https://www.internic.net/domain/named.root -qO- | sudo tee "$LIB_PATH/root.hints"

# Set permissions
sudo chown -R unbound:unbound $LIB_PATH $LOG_PATH $UNBOUND_PATH | tee -a run.log
sudo chmod -R 755 $LIB_PATH $LOG_PATH $UNBOUND_PATH | tee -a run.log

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

# Update sysctl.conf
echo "Appending params to /etc/sysctl.conf"
sudo tee -a /etc/sysctl.conf > /dev/null <<EOT

# Optimize kernel parameters for Unbound DNS resolver:
# These settings improve the performance of Unbound by increasing
# buffer sizes for TCP sockets (critical for DNS over TCP/TLS),
# enabling the 'fq' queuing discipline to reduce latency,
# and using the BBR congestion control algorithm for better
# bandwidth and lower response times.

net.core.rmem_max = 4194304
net.core.wmem_max = 4194304
net.ipv4.tcp_rmem = 4096 87380 4194304
net.ipv4.tcp_wmem = 4096 87380 4194304
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOT
sudo sysctl -p

# Enable unbound
systemctl enable unbound | tee -a run.log

printf "\n"
echo -e "\e[31mWARNING:\e[0m Valid SSL certs required!"
echo -e "\e[31mWARNING:\e[0m \e[32mprivkey.pem\e[0m and \e[32mfullchain.pem\e[0m must be placed in \e[32m$CERT_PATH\e[0m."
echo -e "\e[31mWARNING:\e[0m Unbound will fail to start without a valid SSL certificate"
printf "\n"
echo "Unbound installed successfully!"
