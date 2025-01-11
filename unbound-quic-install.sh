#!/usr/bin/env bash
# Install Unbound 1.22.0 with support for DNS over QUIC

set -o errexit
set -o pipefail

if [ "$EUID" -ne 0 ]
  then echo "Please run the script as root or invoke via sudo."
  exit
fi

rm -f run.log && touch run.log
echo "Extracting Unbound"
tar xzf unbound-quic-1.22.0.tar.gz | tee -a run.log
cd unbound-quic-1.22.0

echo "Generating new user (unbound)"
sudo groupadd --system unbound | tee -a run.log
sudo useradd --system --home /var/lib/unbound --shell /usr/sbin/nologin --ingroup unbound unbound | tee -a run.log

echo "Creating app directories and configuring ownership"
sudo mkdir -p /var/lib/unbound /var/log/unbound /etc/unbound | tee -a run.log
sudo chown -R unbound:unbound /var/lib/unbound /var/log/unbound /etc/unbound | tee -a run.log

# TODO: copy config

# TODO: install extra unbound utils before running these?
sudo -u unbound /usr/local/sbin/unbound-anchor || echo "Unbound-anchor may have failed to update the root.key used to verify DNSSEC signatures." | tee -a run.log
sudo -u unbound /usr/local/sbin/unbound-control-setup | tee -a run.log

# TODO: configure systemd
sudo cp system/unbound.service /etc/systemd/system/unbound.service | tee -a run.log
sudo systemctl daemon-reload

# TODO: configure apparmor
if sudo apparmor_status | grep -q "module is loaded"; then
  sudo cp apparmor.d/usr.sbin.unbound /etc/apparmor.d/usr.sbin.unbound | tee -a run.log
  sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.unbound | tee -a run.log
fi

systemctl enable unbound | tee -a run.log
systemctl restart unbound | tee -a run.log
systemctl status unbound | tee -a run.log
echo "Unbound installed."
