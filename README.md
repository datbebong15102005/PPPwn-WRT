# PPPwn-WRT (Smart Rest Mode / Chiaki Ready)

A highly optimized fork of the original PPPwn_WRT script for OpenWRT routers. This version introduces a **Smart State Machine based on Link Speed** to perfectly support PS4 Rest Mode, ensuring your PPPoE connection stays alive for remote wake-ups via Chiaki or the official Remote Play app!

Based on the original project by [MODDEDWARFARE](https://github.com/MODDEDWARFARE/PPPwn_WRT) and [stooged](https://github.com/stooged/PI-Pwn).

---

## Why use this fork?
Standard PPPwn scripts are brutal: whenever the PS4 enters Rest Mode, the LAN port drops briefly. The script detects this "DOWN" state, instantly kills the PPPoE server, and arms the exploit. **Result:** The PS4 loses internet access in Rest Mode. You **cannot** wake it up remotely.

**How this fork fixes it:**
Instead of blindly checking if the port is UP or DOWN, this script reads the hardware negotiation speed (`/sys/class/net/ethX/speed`) to understand exactly what the PS4 is doing:

* **[ Normal Play ]** --(1000Mbps)--> Router ignores, network is alive.
* **[ Rest Mode ]** --(Drops to 100Mbps)--> Router detects sleep state. **Keep PPPoE alive.** Network stays connected for Chiaki Wake-Up packets!
* **[ Waking Up ]** --(Jumps to 1000Mbps)--> Router knows PS4 just woke up from Rest Mode. GoldHEN is still active. Bypasses the exploit!
* **[ Power Off ]** --(0Mbps)--> Complete shutdown detected. Arms the PPPwn exploit for the next cold boot.

---

## Features

- **100% Chiaki & Remote Play Compatible:** Waking up your PS4 away from home now actually works.
- **VPN / ZeroTier Ready:** Designed to work flawlessly with ZeroTier on OpenWRT to bypass Carrier-Grade NAT (CGNAT) for global Remote Play.
- **Zero-Loop Nmap Checking:** Fixes the infinite "Waiting for IP" loop when verifying GoldHEN status.
- Internet Passthrough over PPPoE after successful Jailbreak
- Autolaunch PPPwn after the PS4 reboots
- Web Panel for loading payloads, adjusting settings & restarting PPPwn
- Option to load PPPwn from the LuCI web interface

---

## Setup & Installation

SSH into your OpenWRT device and run the following commands to download and start the installation:

```sh
wget [https://github.com/datbebong15102005/PPPwn-WRT/raw/main/install.sh](https://github.com/datbebong15102005/PPPwn-WRT/raw/main/install.sh)
chmod +x install.sh && . ./install.sh
```

**⚠️ Important Setup Notes for this Fork:**
During the installation questions, make sure to answer **YES (Y)** to the following options to ensure the Smart Rest Mode works perfectly:
1. `Do you want to detect a console shutdown and relaunch PPPwn?` -> **Y**
2. `Enable GoldHEN detection for rest mode support?` -> **Y**

Once installation completes, your device will reboot.

---

## PS4 Configuration

1. **GoldHEN Payload:**
   - Download the latest `goldhen.bin` from [GoldHEN Releases](https://github.com/GoldHEN/GoldHEN/releases)
   - Place it in the root of a FAT32 or exFAT USB drive and insert it into the PS4.

2. **Set Up Network on PS4:**
   - Go to **Settings > Network > Set Up Internet Connection**
   - Choose **LAN Cable > Custom > PPPoE**
   - Use the credentials (unless changed during install):
     ```text
     Username: ppp
     Password: ppp
     ```

---

## Bonus 1: Enable IPv6 NAT (NAT66) for the Whole Network
If your ISP only provides a single IPv6 address (like a `/128`) or a strict `/64` prefix that prevents proper subnetting (a common issue in many regions), your LAN devices might not get IPv6 access. You can force OpenWRT to use IPv6 NAT (Masquerading) to share that single connection with all devices in your home network. This is highly recommended to achieve the lowest latency for Remote Play!

**1. Configure the LAN Interface:**
* Go to **Network** > **Interfaces** > click **Edit** on your `lan` interface.
* Under the **DHCP Server** tab > **IPv6 Settings**:
  * Set **RA-Service** and **DHCPv6-Service** to `server mode`.
  * Set **NDP-Proxy** to `disabled`.
* Under the **DHCP Server** tab > **IPv6 RA Settings**:
  * Find **Default router** and change it to `forced`. *(Crucial: This forces your devices to route IPv6 traffic through OpenWRT).*
* Click **Save**.

**2. Setup the WAN6 Interface:**
* Go back to **Interfaces** > click **Edit** on your `wan6` (or your IPv6 WAN interface).
* Under the **DHCP Server** tab > **IPv6 Settings**:
  * Uncheck **Designated master**.
  * Set **RA-Service**, **DHCPv6-Service**, and **NDP-Proxy** to `disabled`. *(The WAN interface should only receive IP, not distribute it).*
* Click **Save**.

**3. Enable IPv6 Masquerading (Firewall):**
* Go to **Network** > **Firewall**.
* Click **Edit** on the `wan` zone (usually highlighted in red).
* Check the **IPv6 Masquerading** box in **Advanced Settings**.
* Click **Save & Apply**.

Reconnect your devices (toggle Wi-Fi off and on) and test your connection at [test-ipv6.com](https://test-ipv6.com/). You should now score a perfect 10/10!

---

## Bonus 2: Bypass CGNAT with a VPN (ZeroTier / Tailscale) for Remote Play
If your ISP places you behind a Carrier-Grade NAT (CGNAT), traditional port forwarding won't work. Installing a VPN like ZeroTier or Tailscale directly on your OpenWRT router is the ultimate solution to tunnel back into your home network from anywhere in the world.

**1. Initial Setup**
* Install your preferred VPN package (e.g., `luci-app-zerotier` or `tailscale`) on OpenWRT.
* Join your VPN network and assign the new VPN interface to its own firewall zone (e.g., `VPN_ZONE`).

**2. Configure Firewall Rules**
* Go to **Network** > **Firewall** > **General Settings**.

* **Edit the `lan` zone:**
  * In **Allow forward to destination zones** & **Allow forward from source zones**: Add your VPN interface.
  * Ensure **Input**, **Output**, and **Forward** are set to `accept`.
  * Click **Save**.

* **Edit the `wan` zone:**
  * In **Allow forward from source zones**: Add your VPN interface.
  * Ensure **Input** & **Forward** are `reject`, and **Output** is `accept`.
  * Check the **Masquerading** and **MSS clamping** boxes.
  * Click **Save**.

* **Edit your `VPN` zone:**
  * In **Allow forward to destination zones**: Add both `lan` and `wan` interfaces.
  * In **Allow forward from source zones**: Add the `lan` interface.
  * Change **Input** and **Output** to `accept`, and **Forward** to `reject`.
  * Check the **Masquerading** box *(This is the magic trick that allows VPN traffic to seamlessly NAT into your LAN without complex static routing!)*.
  * Click **Save & Apply**.

* **Edit port forwarding:**
  * In **Firewall** page, go to **Port Forwarding**
  * Add 2 Port Forwarding like this:
    * Port Forwarding 1:
      * Name: PS4_Remote_Play
      * Protocol: TCP & UDP
      * Source zone: Your VPN zone
      * External port: 9295-9304
      * Destination zone: LAN interface
      * Internal IP address: Type your PS4 IP address
      * Internal port: 9295-9304
      * Click **Save** button
    * Port Forwarding 2:
      * Name: PS4_Wakeup_UDP
      * Protocol: UDP
      * Source zone: Your VPN zone
      * External port: 987
      * Destination zone: LAN interface
      * Internal IP address: Type your PS4 IP address
      * Internal port: 987
      * Click **Save** button
  * Click **Save & Apply** button

**Done!** You can now wake up and play your PS4 using Chiaki via the VPN IP address, completely bypassing your ISP's CGNAT!

---

## Credits & Acknowledgements

This project relies on the amazing work of others. Special thanks to:
- **[Nguyễn Trọng Đạt](https://github.com/datanonymus/PPPwn-WRT)** - Redesigned the logic flow, added Link Speed State Machine, fixed Rest Mode/Chiaki functionality, and Nmap loop fix.
- **[MODDEDWARFARE](https://github.com/MODDEDWARFARE/PPPwn_WRT)** - For the original OpenWRT script foundation.
- **[stooged](https://github.com/stooged/PI-Pwn)** - For the Pi-Pwn project.
- **[TheFlow0](https://github.com/TheOfficialFloW/PPPwn)** - For the legendary PPPwn exploit.
- **[xfangfang](https://github.com/xfangfang/PPPwn_cpp)** - For the C++ rewrite of the exploit.
