# Hybrid SOC/Detection Engineering Lab (Wazuh SIEM & Suricata NIDS)

## 📌 Project Overview
Designed and deployed a localized **mini-SOC architecture** leveraging a split-component **Wazuh SIEM stack** (Indexer, Manager, Dashboard) virtualized on an ARM64 environment. Configured a Linux-based hardware endpoint acting as a network sensor running **Suricata NIDS** linked via an authenticated **Wazuh Agent pipeline**. Validated end-to-end telemetry ingestion by simulating adversary reconnaissance techniques via **Kali Linux**, successfully mapping network anomalies to the **MITRE ATT&CK framework** inside the SIEM dashboard.

---

## 🏗️ Architecture Design
The architecture isolates components across three distinct operational roles:
1. **The Ubuntu Server VM (SIEM Core):** Hosts the rule evaluation engine (Wazuh Manager), the analytics indexing database (OpenSearch Indexer), and the monitoring interface (Wazuh Dashboard).
2. **The Raspberry Pi (Endpoint & NIDS Sensor):** Acts as the primary defensive host. Runs Suricata to sniff raw ingress/egress network traffic packets and pipes system logging and packet alerts back to the SIEM via an authenticated Wazuh Agent.
3. **The Kali Linux VM (Adversary Simulation):** Represents the threat actor, utilized to run active network exploitation and reconnaissance tests to validate pipeline visibility.

---

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



💾Step 2: Install and Configure Suricata NIDS

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

