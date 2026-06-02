
# 🏗️ Hybrid SOC & Network Detection Lab (Wazuh SIEM & Suricata NIDS)

## 📌 Project Overview

Designed and deployed a dual-purpose **Endpoint & Network Intrusion Detection System (NIDS)** engineering lab utilizing a hardware-based Raspberry Pi network sensor and a virtualized **Wazuh SIEM stack**. The Raspberry Pi captures raw passive wire traffic utilizing an optimized **Suricata** engine, while a localized **Wazuh Agent** securely streams host and network telemetry out to a central **Wazuh Manager, Indexer, and Dashboard** instance. End-to-end telemetry ingestion and rule mapping were successfully validated by executing adversarial reconnaissance and exploits via **Kali Linux** to map telemetry to the **MITRE ATT&CK Framework**.

---

## 🗺️ Architectural Design & Data Flow

```text
[Kali Linux VM (Attacker)] ---> (Generates Nmap/Malicious Traffic) 
                                       |
                                       v
[Raspberry Pi (Sensor)]   ---> (Suricata Sniffs Traffic -> Writes to eve.json)
                                       |
                                       v
[Wazuh Agent (Shipper)]   ---> (Encrypts & Ships Logs via Port 1514/TCP)
                                       |
                                       v
[Ubuntu Server (SIEM)]    ---> (Decodes, Indexes, & Visualizes in Safari Dashboard)

---
```

## 🚀 Deployment Instructions

### 🛠️ Step 1: Optimize the Raspberry Pi for Packet Capture

1. Log into your Raspberry Pi OS Lite (64-bit) instance via SSH. Before installing the NIDS engine, the hardware interface must be configured to pass all segment frames up the stack without drop anomalies.

2. Persistent Promiscuous Mode Configuration
Force the internal network interface card (NIC) out of standard filtering mode to allow full frame inspection. Create a persistent systemd lifecycle management service unit:

```bash
sudo nano /etc/systemd/system/promisc.service
```

3. Paste the configuration below (replace eth0 with the target network interface identifier derived from ip a):


```
Ini, TOML
[Unit]
Description=Bring up interface in promiscuous mode
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/ip link set eth0 promiscuous on
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```


4. Reload the system daemons

```bash
sudo systemctl daemon-reload && sudo systemctl enable promisc.service --now
```

5. Disable Hardware Packet Offloading

```bash
sudo apt update && sudo apt install ethtool -y
```

* To make execution persistent across reboots: `sudo ethtool -K eth0 gro off lro off`



### 💾Step 2: Install and Configure Suricata NIDS

```bash
sudo apt install suricata -y
sudo nano /etc/suricata/suricata.yaml
```

* Update these values inside the `suricata.yaml` file:
   *HOME_NET: "[192.168.1.0/24]"

   *af-packet interface: eth0

* Verify eve-log is active -> `enabled:yes`

* Initialize Suricata and update signatures to pinpoint malicious vectors

```bash
sudo suricata-update
sudo suricata -T -c /etc/suricata/suricata.yaml -v
sudo systemctl enable suricata --now
```

### 🕵Step 3: Install Wazuh

1. Run the command below to install the Wazuh Manager, Indexer and Dashboard tools
   `curl -sO https://packages.wazuh.com/4.x/wazuh-install.sh && sudo bash wazuh-install.sh -a`
   * **NOTE**: Replace the `x` placeholder from the URL with the latest wazuh version if needed.

2. Once the installation is complete, it'll display the admin credentials log in to the Wazuh web portal. Save them in a secure location. Access the interface at https://<ip-of-your-server> using the generated admin credentials.

### ⛓️‍💥Step 4: Link the Endpoint and NIDS together

1. Open the Wazuh config on your endpoint device: `sudo nano /var/ossec/etc/ossec.conf`
2. Add the Suricata File Monitor:
   * Scroll down to the log-monitoring section and paste this tracking block directly inside the main <ossec_config> wrapper:
  ```xml
   <localfile>
  <log_format>json</log_format>
  <location>/var/log/suricata/eve.json</location>
</localfile>
```

3. Apply changes with `sudo systemctl restart wazuh-agent`
   
