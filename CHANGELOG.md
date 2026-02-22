# Changelog

All notable changes to this project are documented in this file.

## Unreleased

- PaqX-style auto KCP tuning (CPU/RAM-aware) for new Server A / Server B setups
- PaqX-style kernel optimization (BBR, TCP Fast Open, socket buffers) via `/etc/sysctl.d/99-paqet-tunnel.conf`
- Core binary updater for `paqet` (`hanselime/paqet` releases)
- Retrofit auto-tuning for existing configs (`k` menu option)
- Read-only auto profile viewer (`p` menu option)
- Updates submenu grouping installer + core updates
- Main menu now shows installed `paqet` core version
- More robust `paqet` archive extraction with binary auto-detection (less dependent on exact upstream filenames)
- Default KCP MTU baseline changed to `1300`

## v1.11.0

- IPTables Port Forwarding (`f`): kernel-level NAT forwarding (multi-port, all-ports with exclusions, view/remove/flush)

## v1.10.0

- Connection Protection & MTU Tuning (`d`)
  - raw table `NOTRACK`
  - mangle table RST blocking (`PREROUTING` / `OUTPUT`)
  - kernel RST suppression for paqet raw sockets
- Server A now auto-applies client-side protection iptables rules for Server B IP:port
- Default KCP MTU changed from `1350` to `1280`

## v1.9.0

- Automatic Reset (`a`) with configurable interval (1/3/6/12 hours, 1 day, 7 days)
- Enable/disable toggle and manual reset in the same menu

## v1.8.0

- Multi-tunnel support on Server A (`config-<name>.yaml`, `paqet-<name>`)
- Manage Tunnels menu (add/remove/restart/stop/start)
- Status/View/Edit/Test tunnel selection support when multiple tunnels exist

## v1.7.0

- Port Settings in Edit Configuration for V2Ray/paqet port changes without full reconfiguration

## v1.6.0

- Install script as `paqet-tunnel` system command

## v1.5.1

- MTU configuration added to KCP settings

## v1.5.0

- Iran network optimization (DNS finder + apt mirror selector)
- Improved version fetching with raw main branch fallback

## v1.4.0

- Enhanced input validation (retry instead of exit)
- Improved defaults and TCP connectivity messaging

## v1.3.0

- Auto-check `/root/paqet` for local archives before downloading
- Dependency install skip option
- Manual install guidance for restricted networks

## v1.0.0

- Initial release with Server A/B setup
- Config editor for ports/keys/KCP settings
- Connection test tool and auto-updater
