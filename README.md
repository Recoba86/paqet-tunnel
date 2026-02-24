# paqet-tunnel

[English](README.md) | [فارسی](README.fa.md) | [Changelog](CHANGELOG.md)

Easy installer for tunneling VPN traffic through a middle server using [paqet](https://github.com/hanselime/paqet) - a raw packet-level tunneling tool that bypasses network restrictions.

**Current Version:** v1.11.1

## Changelog

### v1.11.1
- **PaqX-style Auto Tuning (CPU/RAM)** - New setups now auto-calculate KCP defaults (`conn`, `rcvwnd`, `sndwnd`) based on server resources
- **PaqX-style Kernel Optimization** - Setup now applies BBR/TCP Fast Open/socket buffer sysctl tuning via a dedicated file in `/etc/sysctl.d/`
- **Core Binary Updater** - New menu option (**b**) to update the `paqet` core binary from `hanselime/paqet` releases (separate from installer self-update)
- **Retrofit Auto-Tune** - New menu option (**k**) to apply the auto-tuned KCP profile to existing configs without recreating tunnels
- **Read-only Auto Profile View** - New menu option (**p**) to inspect detected CPU/RAM and computed KCP values without applying changes
- **Updates Submenu** - Installer and core updates are grouped under a single Updates menu
- **Port Mapping Support (Server A)** - Supports `listen:target` mappings like `1090:443`
- **UDP and Mixed Forwarding** - Supports TCP-only, UDP-only, and mixed mappings (for example `51820/udp`, `1090:443/udp`)
- **Manual Config Editor** - Advanced YAML editor in Edit Configuration with backup + optional restart
- **Forward Generation Hardening** - Fixed empty `forward:` generation edge case and improved mapping rebuild safety

### Unreleased
- No changes yet

### v1.11.0
- **IPTables Port Forwarding** - New menu option (**f**) under Maintenance: kernel-level NAT port forwarding (multi-port, all-ports with exclusions, view/remove/flush). Enables segregated port management and testing backup tunnels without service restarts.

### v1.10.0
- **Connection Protection & MTU Tuning** - New menu option (**d**) under Maintenance to apply iptables rules that:
  - Bypass kernel connection tracking (raw table `NOTRACK`)
  - Block fake RST packets injected by ISP or middleboxes (mangle `PREROUTING`/`OUTPUT`)
  - Prevent the kernel from sending RST packets that interfere with paqet's raw socket tunnel
- **Client-Side Protection** - Server A (Iran) now automatically installs connection protection iptables rules at setup time, targeting Server B's IP:port
- **MTU Default Updated** - Default KCP MTU changed from `1350` to `1280` for better reliability on restrictive networks

### v1.9.0
- **Automatic Reset** - Option (a) for scheduled service restarts (configurable interval)
- Configurable interval: 1/3/6/12 hours, 1 day, or 7 days
- Enable/disable toggle; manual reset now available from the same menu

### v1.8.0
- **Multi-Tunnel Support** - Run multiple named tunnels on Server A, each connecting to a different Server B
- Each tunnel gets its own config file (`config-<name>.yaml`) and systemd service (`paqet-<name>`)
- New **Manage Tunnels** menu (option 6): add, remove, restart, stop, start individual tunnels
- Status check now shows all tunnels at once
- Edit/View/Test operations prompt for tunnel selection when multiple exist
- Server B setup remains unchanged (single instance)

### v1.7.0
- **Port Settings** - Under Edit Configuration (option 5): add, remove, or replace V2Ray/paqet ports without full reconfiguration
- View current port configuration and change paqet tunnel port on both server roles

### v1.6.0
- **Install as Command** - Option to install script as `paqet-tunnel` system command
- Run `paqet-tunnel` anytime without needing curl
- Update/remove command from menu

### v1.5.1
- **MTU Configuration** - Added MTU setting in KCP configuration
- Helps fix EOF errors on restrictive networks (try 1280-1300)

### v1.5.0
- **Iran Network Optimization** - DNS finder and apt mirror selector for Iran servers
- Improved version fetching with fallback to raw main branch

### v1.4.0
- **Enhanced Input Validation** - Won't exit on invalid input, keeps asking until valid
- New default configurations for better out-of-box experience
- Improved TCP connectivity test messaging for raw socket behavior

### v1.3.0
- Auto-check `/root/paqet` for local archives before downloading
- Skip option for dependency installation
- Manual install guide for restricted networks

### v1.0.0
- Initial release with Server A/B setup
- Configuration editor for ports, keys, KCP settings
- Connection test tool and auto-updater

## Features

- **Interactive Setup** - Guided installation for both Iran and abroad servers
- **Multi-Tunnel Support** - Connect one Server A to multiple Server Bs with named tunnels
- **Install as Command** - Run `paqet-tunnel` after installing
- **Port Settings Menu** - Protocol-aware add/remove/replace for TCP/UDP/mixed forward mappings without full reconfiguration
- **Input Validation** - Won't exit on invalid input, keeps asking until valid
- **Iran Network Optimization** - Optional DNS and apt mirror optimization for Iran servers
- **Configuration Editor** - Change ports, keys, KCP settings, and MTU, plus advanced manual YAML editing with backup
- **Connection Test Tool** - Built-in diagnostics to verify tunnel connectivity
- **Auto-Updater** - Check for and install updates from within the script
- **Automatic Reset** - Scheduled service restart for reliability (configurable interval)
- **Smart Defaults** - Sensible defaults with easy customization
- **Connection Protection** - iptables rules and tools to resist fake RST injection and connection drops
- **PaqX-style Auto Tuning** - CPU/RAM-aware KCP defaults for new setups (Server A and Server B)
- **Kernel Optimization (sysctl)** - Applies BBR/TFO/socket buffer tuning via a dedicated file
- **Core Binary Update** - Update `paqet` itself from GitHub releases without reinstalling the script

## Use Case

This tool is designed for users in **Iran** (or other restricted regions) who need to access VPN servers located **abroad**. Instead of connecting directly to your VPN server (which may be blocked or throttled), traffic is routed through a middle server using raw packet tunneling that evades detection.

## Overview

paqet uses raw TCP packet injection to create a tunnel that:

- Bypasses kernel-level connection tracking (conntrack)
- Uses KCP protocol for encrypted, reliable transport
- Is much harder to detect than SSH or VPN protocols
- Evades Deep Packet Inspection (DPI)

## Architecture

### Single Server B

```
┌─────────────┐                              ┌─────────────┐
│  Clients    │                              │   Server B  │
│  (V2Ray)    │                              │  (ABROAD)   │
└──────┬──────┘                              │  VPN Server │
       │                                     │  e.g. USA   │
       │ Connect to                          └──────┬──────┘
       │ Server A IP                                │
       ▼                                            │ V2Ray/X-UI
┌──────────────┐      paqet tunnel           ┌──────▼──────┐
│   Server A   │◄───────────────────────────►│   paqet     │
│   (IRAN)     │     (KCP encrypted)         │   server    │
│ Entry Point  │                             │  port 8888  │
└──────────────┘                             └─────────────┘
```

### Multiple Server Bs

Server A can run multiple named tunnels, each connecting to a different Server B:

```
                                             ┌──────────────┐
                          paqet-usa          │  Server B1   │
                     ┌──────────────────────►│  (USA)       │
                     │   ports 443,8443      │  port 8888   │
┌─────────────┐      │                       └──────────────┘
│  Clients    │      │                       ┌──────────────┐
│  (V2Ray)    │──►┌──┴───────────┐  germany  │  Server B2   │
└─────────────┘   │   Server A   ├──────────►│  (Germany)   │
                  │   (IRAN)     │  port 2053 │  port 8888   │
                  └──┬───────────┘           └──────────────┘
                     │                       ┌──────────────┐
                     │  paqet-france         │  Server B3   │
                     └──────────────────────►│  (France)    │
                         port 2096           │  port 8888   │
                                             └──────────────┘
```

Each tunnel has its own config (`/opt/paqet/config-<name>.yaml`) and service (`paqet-<name>`).

**Servers:**

- **Server A (Iran)**: Entry point server located in Iran - clients connect here
- **Server B (Abroad)**: Your VPN server abroad (USA, Germany, etc.) running V2Ray/X-UI

**Traffic Flow:**

1. Client connects to Server A (Iran) on the V2Ray port
2. Server A tunnels traffic through paqet to Server B (Abroad)
3. Server B forwards to local V2Ray (`127.0.0.1:PORT`)
4. Response flows back through the tunnel

## Quick Start

```bash
# Run on both servers (as root)
bash <(curl -fsSL https://raw.githubusercontent.com/Recoba86/paqet-tunnel/main/install.sh)
```

### Install as Command (Optional)

After running the script, select option **i** to install `paqet-tunnel` as a system command:

```bash
# After installation, you can simply run:
paqet-tunnel
```

This installs the script to `/usr/local/bin/paqet-tunnel` so you can run it anytime without curl.

## Installation Steps

### Step 1: Setup Server B (Abroad - VPN Server)

```bash
ssh root@<SERVER_B_IP>
bash <(curl -fsSL https://raw.githubusercontent.com/Recoba86/paqet-tunnel/main/install.sh)
```

1. Select option **1** (Setup Server B)
2. Confirm network settings (auto-detected)
3. Choose paqet port (default: `8888`)
4. Enter V2Ray port(s) (e.g., `443`)
5. **Save the generated secret key!**

> Setup now applies a PaqX-style auto KCP profile (CPU/RAM-based) and kernel sysctl optimization automatically.

### Step 2: Setup Server A (Iran - Entry Point)

```bash
ssh root@<SERVER_A_IP>
bash <(curl -fsSL https://raw.githubusercontent.com/Recoba86/paqet-tunnel/main/install.sh)
```

> **Note:** If download is blocked in Iran, the installer will ask for a local file path. Download the paqet binary manually and provide the path.

1. Select option **2** (Setup Server A)
2. **Optional:** Run Iran network optimization (DNS + apt mirrors)
3. Enter a **tunnel name** (e.g., `usa`, `germany`)
4. Enter Server B's IP address
5. Enter paqet port: `8888`
6. Enter the **secret key** from Step 1
7. Confirm network settings
8. Choose forwarding mode (`TCP`, `UDP`, or `Both`)
9. Enter forward ports/mappings (examples: `443`, `1090:443`, `51820/udp`, `1090:443/udp`)

To add more tunnels, run setup again (option **2** or via **Manage Tunnels**) with a different name.

> Existing tunnels can be retrofitted later with **Maintenance → k) Apply Auto KCP Tuning (existing configs)**.

#### Iran Network Optimization (Optional)

When setting up Server A, you'll be prompted to run optimization scripts:

```
════════════════════════════════════════════════════════════
          Iran Server Network Optimization                  
════════════════════════════════════════════════════════════

These scripts can help optimize your Iran server:
  1. DNS Finder - Find the best DNS servers for Iran
  2. Mirror Selector - Find the fastest apt repository mirror

Run network optimization scripts before installation? (Y/n):
```

This runs:

- [IranDNSFinder](https://github.com/alinezamifar/IranDNSFinder) - Finds and configures optimal DNS servers
- [DetectUbuntuMirror](https://github.com/alinezamifar/DetectUbuntuMirror) - Selects the fastest apt mirror (Ubuntu/Debian only)

These optimizations can significantly improve download speeds on Iran servers.

### Step 3: Update Client Config

```
# Before (direct to Server B abroad)
vless://uuid@<SERVER_B_IP>:443?type=tcp&...

# After (through Server A in Iran)
vless://uuid@<SERVER_A_IP>:443?type=tcp&...
```

Only change the IP address (and port, if you chose a different listen port on Server A) - everything else stays the same!

## ⚠️ Important: V2Ray Inbound Configuration

On **Server B (Abroad)**, your V2Ray/X-UI inbound **MUST** listen on `0.0.0.0` (all interfaces), not just the public IP or empty.

In X-UI Panel:

1. Go to **Inbounds** → Edit your inbound
2. Set **Listen IP** to: `0.0.0.0`
3. Save and restart X-UI

This is required because paqet forwards traffic to `127.0.0.1:PORT`, and V2Ray must accept connections on localhost.

## Manual Dependency Installation (Iran Servers)

If `apt update` gets stuck due to internet restrictions in Iran, install dependencies manually **before** running the installer:

```bash
# Skip apt update and install from cache
apt install -y --no-install-recommends libpcap-dev iptables curl

# Or install minimal required packages
apt install -y libpcap0.8 iptables curl

# Verify installation
dpkg -l | grep -E "libpcap|iptables|curl"
```

When running the installer, choose **'s'** to skip dependency installation when prompted.

## Performance Optimization

The installer now applies a PaqX-style auto KCP profile during setup (CPU/RAM-aware). For further tuning, or to fix EOF/MTU issues, you can tune KCP from the menu or manually:

### Via Menu (Recommended)

On **both servers**, run the installer and choose:

- **Option 5** → **Edit Configuration**
- Then **Option 3** → **KCP Settings**
- Or use **Maintenance → k** to re-apply the auto profile to existing configs

You can adjust:

- **Mode**: `normal`, `fast`, `fast2`, `fast3`
- **Connections**: number of parallel KCP connections
- **MTU**: default `1300` (try `1280-1300` on problematic networks)

### Manual Tuning Example

Edit the config file on **both servers** (Server B: `config.yaml`, Server A: `config-<name>.yaml`):

```yaml
transport:
  protocol: "kcp"
  conn: 4                    # Multiple parallel connections
  kcp:
    mode: "fast3"            # Aggressive retransmission
    key: "YOUR_SECRET_KEY"
    mtu: 1300                # Baseline default (try 1280–1400 as needed)
    sndwnd: 2048             # Large send window
    rcvwnd: 2048             # Large receive window
    dshard: 10               # FEC error correction
    pshard: 3                # FEC redundancy
```

Then restart:

```bash
# Server B
systemctl restart paqet

# Server A (replace <name> with tunnel name)
systemctl restart paqet-<name>
```

## Menu Options

The installer provides a full management interface:

```
── Setup ──
1) Setup Server B (Abroad - VPN server)
2) Setup Server A (Iran - entry point)

── Management ──
3) Check Status
4) View Configuration
5) Edit Configuration
6) Manage Tunnels (add/remove/restart)
7) Test Connection

── Maintenance ──
8) Updates (installer + core)
k) Apply Auto KCP Tuning (existing configs)
p) View Current Auto Profile
9) Show Port Defaults
a) Automatic Reset (scheduled restart)
d) Connection Protection & MTU Tuning (fix fake RST/disconnects)
f) IPTables Port Forwarding (relay/NAT)
u) Uninstall paqet

── Script ──
i) Install as 'paqet-tunnel' command
r) Remove paqet-tunnel command
0) Exit
```

### IPTables Port Forwarding (Option f)

Forward traffic to another server using kernel-level iptables NAT rules. This is independent of paqet's built-in port forwarding and is especially useful for:

- **Testing backup tunnels** without stopping/restarting the primary tunnel
- **Relay setups** where Server A forwards traffic at the IP level
- **Segregated port management** where each destination has its own set of rules

Submenu options:

- **Multi-Port Forward** - Forward specific ports (TCP+UDP) to a destination IP via DNAT
- **All-Ports Forward** - Forward all traffic except excluded ports (e.g., SSH) to a destination
- **View NAT Rules** - Display current iptables NAT table with line numbers
- **Remove Forwarding by Destination** - Remove all NAT rules targeting a specific IP
- **Flush All NAT Rules** - Clear all NAT rules (does not affect connection protection rules)

The menu also shows a quick status: whether IP forwarding is enabled and how many active DNAT rules exist.

### Manage Tunnels (Option 6)

Add, remove, and control individual tunnels on Server A:

- **Add new tunnel** - Runs Server A setup with a new tunnel name
- **Remove a tunnel** - Stops service and removes config for a selected tunnel
- **Restart/Stop/Start** - Control individual tunnel services

### Edit Configuration (Option 5)

Change settings without manually editing config files. If multiple tunnels exist, you'll be asked which one to edit:

- **Port Settings** - Add, remove, or change V2Ray/paqet ports (see below)
- **Secret Key** - Generate or set a new key
- **KCP Settings** - Adjust mode (normal/fast/fast2/fast3), connections, and MTU
- **Network Interface** - Change the network interface
- **Server B Address** - Update the abroad server IP/port (client only)
- **Manual edit config file (advanced)** - Open the raw YAML in `$EDITOR` / `nano` / `vim` with backup + optional restart

**Port Settings** (first option in Edit Configuration):

**For Server A (Iran/Client):**
- View current forward mappings (TCP/UDP)
- Change paqet tunnel port (connection to Server B)
- Add new forward mapping(s) (TCP/UDP)
- Remove individual forward mapping (TCP/UDP)
- Replace all forward mappings (TCP/UDP)
- Supported formats: `443`, `8443:443`, `51820/udp`, `1090:443/udp`

**For Server B (Abroad/Server):**
- View current paqet tunnel port
- Change paqet tunnel port

### Test Connection (Option 7)

Built-in diagnostics that automatically detect your server role and run appropriate tests:

**Server A (Iran) tests:**

- Service status check
- Network connectivity to Server B
- Forwarded ports verification
- Tunnel activity logs
- End-to-end tunnel test

**Server B (Abroad) tests:**

- Service status check
- Listening port verification
- iptables rules check
- Recent activity logs
- External connectivity

> **Note:** TCP probe tests may show "no response" even when the tunnel works. This is normal - paqet uses raw sockets and doesn't respond to standard TCP probes.

### Updates (Option 8)

The installer groups updates into a small submenu:

- **1) Check/Update Installer Script** - Updates the `paqet-tunnel` installer script itself
- **2) Update paqet Core (binary)** - Updates the `paqet` binary from [hanselime/paqet releases](https://github.com/hanselime/paqet/releases)

**Installer update (sub-option 1):**

- Checks GitHub for the latest version
- Compares with current version
- Downloads and launches the new version automatically
- Backs up existing configuration before updating

**Core update (sub-option 2):**

- Creates a backup of the current binary before replacing it
- Downloads the latest release for the current CPU architecture
- Restarts detected `paqet` services after the update

### Apply Auto KCP Tuning (Option k)

Re-applies the PaqX-style auto-tuned KCP profile to existing `config.yaml` / `config-<name>.yaml` files on the current server.

- Detects CPU cores and RAM on the current server
- Updates KCP settings (`conn`, `mode`, `mtu`, window sizes, FEC/buffer values)
- Creates backup copies of existing configs before editing
- Re-applies kernel sysctl optimization and can restart services automatically

### View Current Auto Profile (Option p)

Shows the computed PaqX-style auto KCP profile for the current server without changing any configs:

- Detected CPU cores and RAM
- Computed KCP `conn`, window sizes, and MTU baseline
- Read-only output (no config or service changes)

## Commands

```bash
# Check status of a tunnel (replace <name> with tunnel name, e.g., usa)
systemctl status paqet-<name>

# View logs
journalctl -u paqet-<name> -f

# Restart a tunnel
systemctl restart paqet-<name>

# View configuration
cat /opt/paqet/config-<name>.yaml

# For Server B (single instance, no name needed)
systemctl status paqet
cat /opt/paqet/config.yaml

# Uninstall
# Run installer again and select option 'u'
```

## Requirements

- Linux server (Ubuntu, Debian, CentOS, etc.)
- Root access
- `libpcap-dev` (auto-installed)
- iptables

## How paqet Works


| Feature           | Description                                           |
| ----------------- | ----------------------------------------------------- |
| **Raw Packets**   | Injects TCP packets directly, bypassing OS networking |
| **Kernel Bypass** | Uses pcap library to bypass conntrack                 |
| **KCP Protocol**  | Encrypted, reliable transport layer                   |
| **RST Blocking**  | Drops kernel RST packets via iptables                 |
| **No Handshake**  | No identifiable protocol signature                    |


## Troubleshooting

**Connection timeout:**

- Verify secret keys match exactly on both servers
- Check iptables rules: `iptables -t raw -L -n`
- Ensure cloud firewall allows the paqet port (8888)
- Make sure V2Ray inbound listens on `0.0.0.0`
- For WireGuard/Hysteria or other UDP services, make sure the forward mapping uses `/udp` and the backend is listening on UDP
- Run the **Test Connection** tool (option 7) for diagnostics

**Download blocked in Iran:**

- Run the **Iran Network Optimization** when prompted during Server A setup
- Download paqet manually from [releases](https://github.com/hanselime/paqet/releases)
- Installer will prompt for local file path

**Port already in use:**

- Installer will detect this and offer to kill the process

**Service not starting:**

- Check logs: `journalctl -u paqet-<name> -n 50`
- Verify config: `cat /opt/paqet/config-<name>.yaml`

**Slow speed:**

- Apply performance optimizations above
- Run **Maintenance → k** to re-apply the auto KCP profile after server upgrades/migrations
- Try increasing `conn` to 8 (use Edit Configuration, option 5)
- Check server CPU/bandwidth limits

**Clients can't connect:**

- Verify V2Ray inbound listens on `0.0.0.0`
- Verify Server A's firewall allows the forwarded ports
- Check both paqet services are running
- Use **Test Connection** (option 7) to diagnose

**TCP probe shows "no response":**

- This is **normal** for paqet - it uses raw sockets
- Run the end-to-end test in Test Connection to verify the tunnel works

## License

MIT License

## Credits

- [paqet](https://github.com/hanselime/paqet) - Raw packet tunneling library by hanselime
