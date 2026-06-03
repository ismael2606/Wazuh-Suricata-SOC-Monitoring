#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run this script with sudo."
  exit 1
fi

# ==========================================
# ⚙️ USER VARIABLES (Modify these before running)
# ==========================================
INTERFACE="eth0"
HOME_SUBNET="192.168.1.0\/24"
WAZUH_MANAGER_IP="192.168.1.206"

echo "Initializing Automated Endpoint & NIDS Setup on Interface: $INTERFACE..."

# ==========================================
# 🛠️ STEP 1: OPTIMIZE INTERFACE
# ==========================================
echo "Configuring Promiscuous Mode Systemd Service..."
cat << EOF > /etc/systemd/system/promisc.service
[Unit]
Description=Bring up interface in promiscuous mode
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/ip link set $INTERFACE promiscuous on
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable promisc.service --now

echo "Disabling Hardware Packet Offloading (GRO/LRO)..."
apt update && apt install ethtool -y
ethtool -K $INTERFACE gro off lro off

# Make offloading persistent by appending to rc.local if it exists
if [ -f /etc/rc.local ]; then
    sed -i -e '$i \ethtool -K '"$INTERFACE"' gro off lro off\n' /etc/rc.local
fi

# ==========================================
# 💾 STEP 2: INSTALL & CONFIGURE SURICATA
# ==========================================
echo "Installing and Configuring Suricata NIDS..."
apt install suricata -y

SURICATA_YML="/etc/suricata/suricata.yaml"
if [ -f "$SURICATA_YML" ]; then
    echo "Modifying suricata.yaml configuration map..."
    # Update HOME_NET and interface mappings using inline sed replacements
    sed -i "s/HOME_NET: \"\[10.0.0.0\/8,172.16.0.0\/12,192.168.0.0\/16\]\"/HOME_NET: \"\[$HOME_SUBNET\]\"/g" $SURICATA_YML
    sed -i "s/interface: eth0/interface: $INTERFACE/g" $SURICATA_YML
fi

echo "Updating threat signatures and restarting Suricata..."
suricata-update
systemctl enable suricata --now

# ==========================================
# ⛓️ STEP 4: DEPLOY & LINK WAZUH AGENT
# ==========================================
echo "Deploying Wazuh Agent Pipeline..."
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor | sudo tee /usr/share/keyrings/wazuh.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | sudo tee /etc/apt/sources.list.d/wazuh.list
apt update && apt install wazuh-agent -y

OSSEC_CONF="/var/ossec/etc/ossec.conf"
if [ -f "$OSSEC_CONF" ]; then
    echo "Linking Agent to Manager IP: $WAZUH_MANAGER_IP..."
    # Insert Manager IP into the address tag
    sed -i "s/<address>MANAGER_IP<\/address>/<address>$WAZUH_MANAGER_IP<\/address>/g" $OSSEC_CONF
    
    echo "Splicing Suricata eve.json monitoring wrapper into ossec.conf..."
    # Append the localfile block right before the closing configuration tag
    sed -i '/<\/ossec_config>/i \  <localfile>\n    <log_format>json<\/log_format>\n    <location>\/var\/log\/suricata\/eve.json<\/location>\n  <\/localfile>\n' $OSSEC_CONF
fi

echo "Initializing all logging streams..."
systemctl daemon-reload
systemctl enable wazuh-agent --now

echo "Deployment finished successfully! Check your Wazuh dashboard for incoming traffice data."
