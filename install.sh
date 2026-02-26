#!/bin/bash
#===============================================================================
#  paqet Tunnel Installer
#  Raw packet-level tunneling for bypassing network restrictions
#  
#  Usage: bash <(curl -fsSL https://raw.githubusercontent.com/Recoba86/paqet-tunnel/main/install.sh)
#  
#  This script downloads paqet binary from: https://github.com/hanselime/paqet
#===============================================================================

set -e

# Configuration
INSTALLER_VERSION="1.11.1"
PAQET_VERSION="latest"
PAQET_DIR="/opt/paqet"
PAQET_CONFIG="$PAQET_DIR/config.yaml"
PAQET_BIN="$PAQET_DIR/paqet"
PAQET_SERVICE="paqet"
AUTO_RESET_CONF="$PAQET_DIR/auto-reset.conf"
AUTO_RESET_SCRIPT="$PAQET_DIR/auto-reset.sh"
AUTO_RESET_SERVICE="paqet-auto-reset"
AUTO_RESET_TIMER="paqet-auto-reset"
GITHUB_REPO="hanselime/paqet"
OPTIMIZED_CORE_RELEASE_REPO="behzadea12/Paqet-Tunnel-Manager"
OPTIMIZED_CORE_RELEASE_TAG="PaqetOptimized"
INSTALLER_REPO="Recoba86/paqet-tunnel"
INSTALLER_CMD="/usr/local/bin/paqet-tunnel"
CORE_PROVIDER_META="$PAQET_DIR/core-provider.env"
CORE_PROFILE_META="$PAQET_DIR/core-profile.env"
CORE_INSTALLED_META="$PAQET_DIR/core-installed.env"
PAQET_CORE_CACHE_DIR="$PAQET_DIR/core-cache"
PAQET_CORE_CACHE_ARCHIVE_DIR="$PAQET_CORE_CACHE_DIR/archives"
DEFAULT_CORE_PROVIDER="official"
DEFAULT_CORE_PROFILE_PRESET="default"
DONATE_TON="UQCriHkMUa6h9oN059tyC23T13OsQhGGM3hUS2S4IYRBZgvx"
DONATE_USDT_BEP20="0x71F41696c60C4693305e67eE3Baa650a4E3dA796"

#===============================================================================
# Default Port Configuration (Easy to change)
#===============================================================================
DEFAULT_PAQET_PORT="8888"           # Port for paqet tunnel communication
DEFAULT_FORWARD_PORTS="9090"        # Default ports to forward (comma-separated)
DEFAULT_KCP_MODE="fast"             # KCP mode: normal, fast, fast2, fast3
DEFAULT_KCP_CONN="1"                # Number of parallel connections
DEFAULT_KCP_MTU="1300"              # Baseline MTU (use maintenance menu to lower to 1280 if needed)
DEFAULT_KCP_DSHARD="10"             # KCP FEC data shards
DEFAULT_KCP_PSHARD="3"              # KCP FEC parity shards
OPTIMIZE_SYSCTL_FILE="/etc/sysctl.d/99-paqet-tunnel.conf"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

print_banner_line() {
    printf "║ %-45s ║\n" "$1"
}

print_banner() {
    clear 2>/dev/null || true
    echo -e "${MAGENTA}"
    echo "╔═══════════════════════════════════════════════╗"
    print_banner_line ""
    print_banner_line "██████╗  █████╗  ██████╗ ███████╗████████╗   "
    print_banner_line "██╔══██╗██╔══██╗██╔═══██╗██╔════╝╚══██╔══╝   "
    print_banner_line "██████╔╝███████║██║   ██║█████╗     ██║      "
    print_banner_line "██╔═══╝ ██╔══██║██║▄▄ ██║██╔══╝     ██║      "
    print_banner_line "██║     ██║  ██║╚██████╔╝███████╗   ██║      "
    print_banner_line "╚═╝     ╚═╝  ╚═╝ ╚══▀▀═╝ ╚══════╝   ╚═╝      "
    print_banner_line ""
    print_banner_line "Raw Packet Tunnel - Firewall Bypass"
    print_banner_line "Version: v${INSTALLER_VERSION}"
    print_banner_line "Created by g3ntrix"
    print_banner_line "Support this project: press 'h' in main menu"
    print_banner_line ""
    echo "╚═══════════════════════════════════════════════╝"
    echo -e "${NC}"
}
show_donate_info() {
    print_banner
    echo -e "${YELLOW}Support paqet-tunnel${NC}"
    echo -e "${CYAN}If this script helps your setup, donations are appreciated.${NC}"
    echo ""
    echo -e "${GREEN}TON:${NC}"
    echo -e "  ${CYAN}${DONATE_TON}${NC}"
    echo ""
    echo -e "${GREEN}USDT (BEP20):${NC}"
    echo -e "  ${CYAN}${DONATE_USDT_BEP20}${NC}"
    echo ""
    print_info "Send only TON to TON address and USDT on BEP20 network to BEP20 address."
}

print_step() { echo -e "${BLUE}[*]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_info() { echo -e "${CYAN}[i]${NC} $1"; }

#===============================================================================
# Core Provider + Profile Preset Metadata
#===============================================================================

PROFILE_PRESET_NAME="$DEFAULT_CORE_PROFILE_PRESET"
PROFILE_PRESET_LABEL="Current Default (PaqX-style)"
PROFILE_PRESET_KCP_BLOCK="aes"
PROFILE_PRESET_KCP_MTU="$DEFAULT_KCP_MTU"
PROFILE_PRESET_TRANSPORT_TCPBUF=""
PROFILE_PRESET_TRANSPORT_UDPBUF=""
PROFILE_PRESET_PCAP_SOCKBUF_SERVER=""
PROFILE_PRESET_PCAP_SOCKBUF_CLIENT=""

get_current_core_provider() {
    if [ -n "${PAQET_CORE_PROVIDER_OVERRIDE:-}" ]; then
        case "$PAQET_CORE_PROVIDER_OVERRIDE" in
            official|behzad-optimized)
                echo "$PAQET_CORE_PROVIDER_OVERRIDE"
                return 0
                ;;
        esac
    fi

    local provider="$DEFAULT_CORE_PROVIDER"
    if [ -f "$CORE_PROVIDER_META" ]; then
        local meta_provider=""
        meta_provider=$(grep '^CORE_PROVIDER=' "$CORE_PROVIDER_META" 2>/dev/null | head -1 | cut -d'"' -f2)
        [ -n "$meta_provider" ] && provider="$meta_provider"
    fi
    case "$provider" in
        official|behzad-optimized) ;;
        *) provider="$DEFAULT_CORE_PROVIDER" ;;
    esac
    echo "$provider"
}

get_core_provider_label() {
    local provider="${1:-$(get_current_core_provider)}"
    case "$provider" in
        official) echo "Official (hanselime/paqet)" ;;
        behzad-optimized) echo "Behzad Optimized (PaqetOptimized)" ;;
        *) echo "Unknown ($provider)" ;;
    esac
}

set_current_core_provider() {
    local provider="$1"
    mkdir -p "$PAQET_DIR"
    cat > "$CORE_PROVIDER_META" << EOF
# paqet-tunnel core provider metadata
CORE_PROVIDER="${provider}"
UPDATED_AT="$(date -Iseconds 2>/dev/null || date)"
EOF
}

get_installed_core_meta_field() {
    local field="$1"
    if [ ! -f "$CORE_INSTALLED_META" ]; then
        echo ""
        return 0
    fi
    grep "^${field}=" "$CORE_INSTALLED_META" 2>/dev/null | head -1 | cut -d'"' -f2
}

set_installed_core_metadata() {
    local provider="$1"
    local version="$2"
    local archive_name="$3"
    mkdir -p "$PAQET_DIR"
    cat > "$CORE_INSTALLED_META" << EOF
# paqet-tunnel installed core metadata
CORE_PROVIDER="${provider}"
CORE_VERSION="${version}"
CORE_ARCHIVE="${archive_name}"
UPDATED_AT="$(date -Iseconds 2>/dev/null || date)"
EOF
}

sanitize_cache_component() {
    local value="$1"
    value=${value//\//_}
    value=${value// /_}
    value=${value//:/_}
    printf '%s\n' "$value"
}

get_paqet_core_archive_cache_path() {
    local provider="$1"
    local version="$2"
    local archive_name="$3"

    local safe_provider=""
    local safe_version=""
    safe_provider=$(sanitize_cache_component "$provider")
    safe_version=$(sanitize_cache_component "$version")

    printf '%s/%s/%s/%s\n' "$PAQET_CORE_CACHE_ARCHIVE_DIR" "$safe_provider" "$safe_version" "$archive_name"
}

get_current_profile_preset() {
    local preset="$DEFAULT_CORE_PROFILE_PRESET"
    if [ -f "$CORE_PROFILE_META" ]; then
        local meta_preset=""
        meta_preset=$(grep '^CORE_PROFILE_PRESET=' "$CORE_PROFILE_META" 2>/dev/null | head -1 | cut -d'"' -f2)
        [ -n "$meta_preset" ] && preset="$meta_preset"
    fi
    case "$preset" in
        default|behzad) ;;
        *) preset="$DEFAULT_CORE_PROFILE_PRESET" ;;
    esac
    echo "$preset"
}

get_profile_preset_label() {
    local preset="${1:-$(get_current_profile_preset)}"
    case "$preset" in
        default) echo "Current Default (PaqX-style baseline)" ;;
        behzad) echo "Behzad Preset (minimal: conn/mode/block/mtu)" ;;
        *) echo "Unknown ($preset)" ;;
    esac
}

set_current_profile_preset() {
    local preset="$1"
    mkdir -p "$PAQET_DIR"
    cat > "$CORE_PROFILE_META" << EOF
# paqet-tunnel core/profile preset metadata
CORE_PROFILE_PRESET="${preset}"
UPDATED_AT="$(date -Iseconds 2>/dev/null || date)"
EOF
}

load_active_profile_preset_defaults() {
    local preset="${1:-}"
    [ -z "$preset" ] && preset=$(get_current_profile_preset)

    PROFILE_PRESET_NAME="$preset"
    PROFILE_PRESET_LABEL="$(get_profile_preset_label "$preset")"
    PROFILE_PRESET_KCP_BLOCK="aes"
    PROFILE_PRESET_KCP_MTU="$DEFAULT_KCP_MTU"
    PROFILE_PRESET_TRANSPORT_TCPBUF=""
    PROFILE_PRESET_TRANSPORT_UDPBUF=""
    PROFILE_PRESET_PCAP_SOCKBUF_SERVER=""
    PROFILE_PRESET_PCAP_SOCKBUF_CLIENT=""

    case "$preset" in
        behzad)
            PROFILE_PRESET_KCP_BLOCK="aes-128-gcm"
            PROFILE_PRESET_KCP_MTU="1150"
            # Match Behzad manager's common default-generated minimal KCP config style.
            # tcpbuf/udpbuf/pcap.sockbuf are optional there and are often omitted unless
            # the user explicitly sets them during the interactive install.
            PROFILE_PRESET_TRANSPORT_TCPBUF=""
            PROFILE_PRESET_TRANSPORT_UDPBUF=""
            PROFILE_PRESET_PCAP_SOCKBUF_SERVER=""
            PROFILE_PRESET_PCAP_SOCKBUF_CLIENT=""
            ;;
    esac
}

build_profile_transport_buffer_fragment() {
    local varname="$1"
    load_active_profile_preset_defaults

    local fragment=""
    [ -n "$PROFILE_PRESET_TRANSPORT_TCPBUF" ] && fragment="${fragment}
  tcpbuf: ${PROFILE_PRESET_TRANSPORT_TCPBUF}"
    [ -n "$PROFILE_PRESET_TRANSPORT_UDPBUF" ] && fragment="${fragment}
  udpbuf: ${PROFILE_PRESET_TRANSPORT_UDPBUF}"

    printf -v "$varname" '%s' "$fragment"
}

build_profile_network_pcap_fragment() {
    local role="$1"   # server or client
    local varname="$2"
    load_active_profile_preset_defaults

    local sockbuf=""
    if [ "$role" = "server" ]; then
        sockbuf="$PROFILE_PRESET_PCAP_SOCKBUF_SERVER"
    else
        sockbuf="$PROFILE_PRESET_PCAP_SOCKBUF_CLIENT"
    fi

    local fragment=""
    if [ -n "$sockbuf" ]; then
        fragment="  pcap:
    sockbuf: ${sockbuf}"
    fi

    printf -v "$varname" '%s' "$fragment"
}

get_effective_profile_kcp_block() {
    load_active_profile_preset_defaults
    echo "$PROFILE_PRESET_KCP_BLOCK"
}

get_effective_profile_kcp_mtu() {
    load_active_profile_preset_defaults
    echo "$PROFILE_PRESET_KCP_MTU"
}

profile_preset_is_behzad() {
    [ "$(get_current_profile_preset)" = "behzad" ]
}

get_effective_profile_conn_value() {
    load_active_profile_preset_defaults
    if [ "$PROFILE_PRESET_NAME" = "behzad" ]; then
        echo "4"
    else
        echo "$AUTO_TUNE_CONN"
    fi
}

build_profile_kcp_extra_fragment() {
    local varname="$1"
    load_active_profile_preset_defaults

    # Behzad preset intentionally keeps KCP config minimal (mode/key/block/mtu + fixed conn)
    # and avoids PaqX CPU/RAM window/FEC/smux auto tuning.
    if [ "$PROFILE_PRESET_NAME" = "behzad" ]; then
        printf -v "$varname" '%s' ""
        return 0
    fi

    local fragment="    nodelay: 1
    interval: 10
    resend: 2
    nocongestion: 1
    wdelay: false
    acknodelay: true
    rcvwnd: ${AUTO_TUNE_RCVWND}
    sndwnd: ${AUTO_TUNE_SNDWND}
    smuxbuf: ${AUTO_TUNE_SMUXBUF}
    streambuf: ${AUTO_TUNE_STREAMBUF}
    dshard: ${DEFAULT_KCP_DSHARD}
    pshard: ${DEFAULT_KCP_PSHARD}"
    printf -v "$varname" '%s' "$fragment"
}

remove_paqx_kcp_tuning_keys() {
    local config_file="$1"

    # Remove PaqX-specific KCP tuning keys so non-PaqX presets (e.g., Behzad) stay clean/minimal.
    sed -i \
        -e '/^[[:space:]]*nodelay:[[:space:]]*/d' \
        -e '/^[[:space:]]*interval:[[:space:]]*/d' \
        -e '/^[[:space:]]*resend:[[:space:]]*/d' \
        -e '/^[[:space:]]*nocongestion:[[:space:]]*/d' \
        -e '/^[[:space:]]*wdelay:[[:space:]]*/d' \
        -e '/^[[:space:]]*acknodelay:[[:space:]]*/d' \
        -e '/^[[:space:]]*rcvwnd:[[:space:]]*/d' \
        -e '/^[[:space:]]*sndwnd:[[:space:]]*/d' \
        -e '/^[[:space:]]*smuxbuf:[[:space:]]*/d' \
        -e '/^[[:space:]]*streambuf:[[:space:]]*/d' \
        -e '/^[[:space:]]*dshard:[[:space:]]*/d' \
        -e '/^[[:space:]]*pshard:[[:space:]]*/d' \
        "$config_file"
}

#===============================================================================
# PaqX-style Auto Tuning (CPU/RAM + kernel sysctl)
#===============================================================================

AUTO_TUNE_CPU_CORES="1"
AUTO_TUNE_MEM_MB="0"
AUTO_TUNE_CONN="$DEFAULT_KCP_CONN"
AUTO_TUNE_SNDWND="1024"
AUTO_TUNE_RCVWND="1024"
AUTO_TUNE_SMUXBUF="4194304"
AUTO_TUNE_STREAMBUF="2097152"

detect_total_mem_mb() {
    local total_mem=""
    if command -v free >/dev/null 2>&1; then
        total_mem=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}')
    fi
    if [ -z "$total_mem" ] && [ -r /proc/meminfo ]; then
        total_mem=$(awk '/^MemTotal:/{print int($2/1024)}' /proc/meminfo 2>/dev/null)
    fi
    [ -z "$total_mem" ] && total_mem="0"
    echo "$total_mem"
}

detect_cpu_cores() {
    local cpu_cores=""
    if command -v nproc >/dev/null 2>&1; then
        cpu_cores=$(nproc 2>/dev/null)
    fi
    [ -z "$cpu_cores" ] && cpu_cores=$(getconf _NPROCESSORS_ONLN 2>/dev/null || true)
    [ -z "$cpu_cores" ] && cpu_cores="1"
    echo "$cpu_cores"
}

calculate_auto_kcp_profile() {
    if profile_preset_is_behzad; then
        # Behzad preset is intentionally fixed and does not use PaqX CPU/RAM auto tuning.
        AUTO_TUNE_MEM_MB=$(detect_total_mem_mb)
        AUTO_TUNE_CPU_CORES=$(detect_cpu_cores)
        AUTO_TUNE_CONN="4"
        AUTO_TUNE_SNDWND="0"
        AUTO_TUNE_RCVWND="0"
        AUTO_TUNE_SMUXBUF="0"
        AUTO_TUNE_STREAMBUF="0"
        return 0
    fi

    calculate_paqx_auto_kcp_profile
}

calculate_paqx_auto_kcp_profile() {
    AUTO_TUNE_MEM_MB=$(detect_total_mem_mb)
    AUTO_TUNE_CPU_CORES=$(detect_cpu_cores)

    # PaqX server auto-tuning thresholds
    AUTO_TUNE_CONN="$DEFAULT_KCP_CONN"
    AUTO_TUNE_SNDWND="1024"
    AUTO_TUNE_RCVWND="1024"
    AUTO_TUNE_SMUXBUF="4194304"
    AUTO_TUNE_STREAMBUF="2097152"

    if [ "$AUTO_TUNE_MEM_MB" -gt 4000 ]; then
        AUTO_TUNE_SNDWND="4096"
        AUTO_TUNE_RCVWND="4096"
    elif [ "$AUTO_TUNE_MEM_MB" -gt 1000 ]; then
        AUTO_TUNE_SNDWND="2048"
        AUTO_TUNE_RCVWND="2048"
    fi

    if [ "$AUTO_TUNE_CPU_CORES" -ge 4 ]; then
        AUTO_TUNE_CONN="4"
    elif [ "$AUTO_TUNE_CPU_CORES" -ge 2 ]; then
        AUTO_TUNE_CONN="2"
    else
        AUTO_TUNE_CONN="$DEFAULT_KCP_CONN"
    fi

    return 0
}

show_auto_kcp_profile() {
    load_active_profile_preset_defaults
    echo -e "${YELLOW}Active KCP Profile Preview:${NC}"
    echo -e "  Profile preset:    ${CYAN}${PROFILE_PRESET_NAME}${NC} (${PROFILE_PRESET_LABEL})"
    echo -e "  CPU cores:        ${CYAN}${AUTO_TUNE_CPU_CORES}${NC}"
    echo -e "  RAM:              ${CYAN}${AUTO_TUNE_MEM_MB} MB${NC}"
    echo -e "  KCP mode:         ${CYAN}${DEFAULT_KCP_MODE}${NC}"
    if [ "$PROFILE_PRESET_NAME" = "behzad" ]; then
        echo -e "  KCP conn:         ${CYAN}4${NC} (Behzad fixed preset)"
    else
        echo -e "  KCP conn:         ${CYAN}${AUTO_TUNE_CONN}${NC} (PaqX CPU/RAM auto-tune)"
    fi
    echo -e "  KCP mtu:          ${CYAN}${PROFILE_PRESET_KCP_MTU}${NC}"
    echo -e "  KCP block:        ${CYAN}${PROFILE_PRESET_KCP_BLOCK}${NC}"
    if [ "$PROFILE_PRESET_NAME" = "behzad" ]; then
        echo -e "  KCP rcvwnd/sndwnd ${CYAN}paqet core defaults (not forced)${NC}"
    else
        echo -e "  KCP rcvwnd/sndwnd ${CYAN}${AUTO_TUNE_RCVWND}/${AUTO_TUNE_SNDWND}${NC}"
    fi
    echo ""
}

apply_paqx_kernel_optimizations() {
    print_step "Applying PaqX-style kernel optimization (BBR/TFO/socket buffers)..."

    # RAM-aware kernel tuning to reduce ENOBUFS/burst drops without overcommitting
    # small VPS instances. These are generic transport-level improvements and do
    # not change tunnel ports/IPs/config mappings.
    calculate_auto_kcp_profile >/dev/null 2>&1 || true
    local mem_mb="${AUTO_TUNE_MEM_MB:-0}"
    local netdev_backlog="65536"
    local sock_max="33554432"
    local sock_default="16777216"
    local tcp_buf_max="33554432"
    local udp_mem_triplet="32768 49152 65536"
    local udp_min="16384"
    local optmem_max="8388608"

    if [ "$mem_mb" -ge 4096 ]; then
        netdev_backlog="250000"
        sock_max="134217728"
        sock_default="33554432"
        tcp_buf_max="134217728"
        udp_mem_triplet="90219 120292 180438"
        udp_min="65536"
        optmem_max="25165824"
    elif [ "$mem_mb" -ge 2048 ]; then
        netdev_backlog="131072"
        sock_max="67108864"
        sock_default="16777216"
        tcp_buf_max="67108864"
        udp_mem_triplet="65536 98304 131072"
        udp_min="65536"
        optmem_max="16777216"
    fi

    mkdir -p /etc/sysctl.d
    cat > "$OPTIMIZE_SYSCTL_FILE" << EOF
# paqet-tunnel kernel optimizations (PaqX-style) - safe to remove
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
fs.file-max=1000000
net.core.netdev_max_backlog=${netdev_backlog}
net.core.optmem_max=${optmem_max}
net.core.rmem_max=${sock_max}
net.core.wmem_max=${sock_max}
net.core.rmem_default=${sock_default}
net.core.wmem_default=${sock_default}
net.ipv4.tcp_rmem=4096 87380 ${tcp_buf_max}
net.ipv4.tcp_wmem=4096 65536 ${tcp_buf_max}
net.ipv4.udp_mem=${udp_mem_triplet}
net.ipv4.udp_rmem_min=${udp_min}
net.ipv4.udp_wmem_min=${udp_min}
EOF

    if sysctl --system >/dev/null 2>&1; then
        print_success "Kernel optimization applied via $OPTIMIZE_SYSCTL_FILE"
        print_info "Kernel burst profile: RAM=${mem_mb}MB backlog=${netdev_backlog} sockmax=${sock_max} udp_mem='${udp_mem_triplet}'"
    else
        print_warning "sysctl reload reported an issue (file was still written to $OPTIMIZE_SYSCTL_FILE)"
    fi
}

#===============================================================================
# Input Validation Functions (with retry on invalid input)
#===============================================================================

# Read required input - keeps asking until valid input is provided
# Usage: read_required "prompt" "variable_name" ["default_value"]
read_required() {
    local prompt="$1"
    local varname="$2"
    local default="$3"
    local value=""
    
    while true; do
        if [ -n "$default" ]; then
            echo -e "${YELLOW}${prompt} [${default}]:${NC}"
        else
            echo -e "${YELLOW}${prompt}:${NC}"
        fi
        read -p "> " value < /dev/tty
        
        # Use default if provided and input is empty
        if [ -z "$value" ] && [ -n "$default" ]; then
            value="$default"
        fi
        
        # Validate non-empty
        if [ -n "$value" ]; then
            eval "$varname='$value'"
            return 0
        else
            print_error "This field is required. Please enter a value."
            echo ""
        fi
    done
}

# Read IP address with validation
# Usage: read_ip "prompt" "variable_name" ["default_value"]
read_ip() {
    local prompt="$1"
    local varname="$2"
    local default="$3"
    local value=""
    local ip_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    while true; do
        if [ -n "$default" ]; then
            echo -e "${YELLOW}${prompt} [${default}]:${NC}"
        else
            echo -e "${YELLOW}${prompt}:${NC}"
        fi
        read -p "> " value < /dev/tty
        
        # Use default if provided and input is empty
        if [ -z "$value" ] && [ -n "$default" ]; then
            value="$default"
        fi
        
        # Validate IP format
        if [ -z "$value" ]; then
            print_error "IP address is required. Please enter a valid IP."
            echo ""
        elif ! [[ "$value" =~ $ip_regex ]]; then
            print_error "Invalid IP format. Please enter a valid IPv4 address (e.g., 192.168.1.1)"
            echo ""
        else
            eval "$varname='$value'"
            return 0
        fi
    done
}

# Read port number with validation
# Usage: read_port "prompt" "variable_name" ["default_value"]
read_port() {
    local prompt="$1"
    local varname="$2"
    local default="$3"
    local value=""
    
    while true; do
        if [ -n "$default" ]; then
            echo -e "${YELLOW}${prompt} [${default}]:${NC}"
        else
            echo -e "${YELLOW}${prompt}:${NC}"
        fi
        read -p "> " value < /dev/tty
        
        # Use default if provided and input is empty
        if [ -z "$value" ] && [ -n "$default" ]; then
            value="$default"
        fi
        
        # Validate port number
        if [ -z "$value" ]; then
            print_error "Port number is required."
            echo ""
        elif ! [[ "$value" =~ ^[0-9]+$ ]]; then
            print_error "Invalid port. Please enter a number."
            echo ""
        elif [ "$value" -lt 1 ] || [ "$value" -gt 65535 ]; then
            print_error "Port must be between 1 and 65535."
            echo ""
        else
            eval "$varname='$value'"
            return 0
        fi
    done
}

# Read port list with validation (comma-separated)
# Usage: read_ports "prompt" "variable_name" ["default_value"]
read_ports() {
    local prompt="$1"
    local varname="$2"
    local default="$3"
    local value=""
    
    while true; do
        if [ -n "$default" ]; then
            echo -e "${YELLOW}${prompt} [${default}]:${NC}"
        else
            echo -e "${YELLOW}${prompt}:${NC}"
        fi
        read -p "> " value < /dev/tty
        
        # Use default if provided and input is empty
        if [ -z "$value" ] && [ -n "$default" ]; then
            value="$default"
        fi
        
        # Validate port list
        if [ -z "$value" ]; then
            print_error "At least one port is required."
            echo ""
            continue
        fi
        
        # Validate each port in the comma-separated list
        local valid=true
        IFS=',' read -ra ports <<< "$value"
        for port in "${ports[@]}"; do
            port=$(echo "$port" | tr -d ' ')
            if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
                print_error "Invalid port: $port. Each port must be a number between 1-65535."
                valid=false
                break
            fi
        done
        
        if [ "$valid" = true ]; then
            eval "$varname='$value'"
            return 0
        fi
        echo ""
    done
}

# Parse and validate forward mapping list (Server A)
# Supports:
#   443                -> listen 443, target 443, tcp
#   8443:443           -> listen 8443, target 443, tcp
#   51820/udp          -> listen 51820, target 51820, udp
#   1090:443/tcp       -> listen 1090, target 443, tcp
#   1090:443/udp       -> listen 1090, target 443, udp
#   443,51820/udp      -> mixed entries
# Returns normalized CSV (duplicates removed by validation):
#   443,51820/udp,8443:443/udp
normalize_forward_mappings_input() {
    local raw_input="$1"
    local varname="$2"
    local default_protocol="${3:-tcp}"
    local normalized_input=""
    local normalized_output=""

    # Accept commas and/or spaces as separators
    normalized_input=$(echo "$raw_input" | tr '[:space:]' ',' | sed 's/,,*/,/g; s/^,//; s/,$//')

    if [ -z "$normalized_input" ]; then
        print_error "At least one forward port or mapping is required."
        return 1
    fi

    local seen_keys=""
    local item=""

    IFS=',' read -ra items <<< "$normalized_input"
    for item in "${items[@]}"; do
        item=$(echo "$item" | tr -d ' ')
        [ -z "$item" ] && continue

        local listen_port=""
        local target_port=""
        local protocol="$default_protocol"

        # Optional protocol suffix (/tcp or /udp)
        if [[ "$item" =~ ^(.+)/(tcp|udp)$ ]]; then
            item="${BASH_REMATCH[1]}"
            protocol="${BASH_REMATCH[2]}"
        fi

        if [[ "$item" =~ ^([0-9]+):([0-9]+)$ ]]; then
            listen_port="${BASH_REMATCH[1]}"
            target_port="${BASH_REMATCH[2]}"
        elif [[ "$item" =~ ^[0-9]+$ ]]; then
            listen_port="$item"
            target_port="$item"
        else
            print_error "Invalid mapping: $item (use PORT or LISTEN:TARGET, optionally /tcp or /udp)"
            return 1
        fi

        if [ "$listen_port" -lt 1 ] || [ "$listen_port" -gt 65535 ]; then
            print_error "Invalid listen port: $listen_port (must be 1-65535)"
            return 1
        fi
        if [ "$target_port" -lt 1 ] || [ "$target_port" -gt 65535 ]; then
            print_error "Invalid target port: $target_port (must be 1-65535)"
            return 1
        fi

        local seen_key="${protocol}:${listen_port}"
        if echo " $seen_keys " | grep -qw "$seen_key"; then
            print_error "Duplicate listen/protocol pair: ${listen_port}/${protocol}"
            return 1
        fi
        seen_keys="${seen_keys} ${seen_key}"

        local spec="$listen_port"
        [ "$listen_port" != "$target_port" ] && spec="${listen_port}:${target_port}"
        [ "$protocol" = "udp" ] && spec="${spec}/udp"
        normalized_output="${normalized_output:+$normalized_output,}$spec"
    done

    if [ -z "$normalized_output" ]; then
        print_error "No valid forward ports/mappings were provided."
        return 1
    fi

    printf -v "$varname" '%s' "$normalized_output"
    return 0
}

read_forward_mappings() {
    local prompt="$1"
    local varname="$2"
    local default="$3"
    local default_protocol="${4:-tcp}"
    local value=""

    while true; do
        if [ -n "$default" ]; then
            echo -e "${YELLOW}${prompt} [${default}]:${NC}"
        else
            echo -e "${YELLOW}${prompt}:${NC}"
        fi
        if [ "$default_protocol" = "udp" ]; then
            echo -e "${CYAN}Format:${NC} 51820 (same UDP), 1090:443, or 1090:443/udp"
        else
            echo -e "${CYAN}Format:${NC} 443 (same TCP), 8443:443, 8443:443/tcp, or append /udp for UDP"
        fi
        read -p "> " value < /dev/tty

        if [ -z "$value" ] && [ -n "$default" ]; then
            value="$default"
        fi

        local normalized_mappings=""
        if normalize_forward_mappings_input "$value" normalized_mappings "$default_protocol"; then
            if [ -z "$normalized_mappings" ]; then
                print_error "Internal error: normalized forward mappings are empty."
                echo ""
                continue
            fi
            printf -v "$varname" '%s' "$normalized_mappings"
            return 0
        fi
        echo ""
    done
}

mapping_listen_port() {
    local spec="$1"
    spec="${spec%%/*}"
    echo "${spec%%:*}"
}

mapping_target_port() {
    local spec="$1"
    spec="${spec%%/*}"
    if [[ "$spec" == *:* ]]; then
        echo "${spec##*:}"
    else
        echo "${spec%%:*}"
    fi
}

mapping_protocol() {
    local spec="$1"
    if [[ "$spec" == */udp ]]; then
        echo "udp"
    else
        echo "tcp"
    fi
}

build_forward_config_from_mappings_csv() {
    local mappings_csv="$1"
    local varname="$2"
    local rendered_forward_config=""
    local spec=""

    IFS=',' read -ra mapping_specs <<< "$mappings_csv"
    for spec in "${mapping_specs[@]}"; do
        spec=$(echo "$spec" | tr -d ' ')
        [ -z "$spec" ] && continue

        local listen_port
        local target_port
        local protocol
        listen_port=$(mapping_listen_port "$spec")
        target_port=$(mapping_target_port "$spec")
        protocol=$(mapping_protocol "$spec")

        rendered_forward_config="${rendered_forward_config}
  - listen: \"0.0.0.0:${listen_port}\"
    target: \"127.0.0.1:${target_port}\"
    protocol: \"${protocol}\""
    done

    if [ -z "$rendered_forward_config" ]; then
        return 1
    fi

    printf -v "$varname" '%s' "$rendered_forward_config"
    return 0
}

# Read MAC address with validation
# Usage: read_mac "prompt" "variable_name" ["default_value"]
read_mac() {
    local prompt="$1"
    local varname="$2"
    local default="$3"
    local value=""
    local mac_regex='^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$'
    
    while true; do
        if [ -n "$default" ]; then
            echo -e "${YELLOW}${prompt} [${default}]:${NC}"
        else
            echo -e "${YELLOW}${prompt}:${NC}"
        fi
        read -p "> " value < /dev/tty
        
        # Use default if provided and input is empty
        if [ -z "$value" ] && [ -n "$default" ]; then
            value="$default"
        fi
        
        # Validate MAC format
        if [ -z "$value" ]; then
            print_error "MAC address is required."
            echo ""
        elif ! [[ "$value" =~ $mac_regex ]]; then
            print_error "Invalid MAC format. Please use format: aa:bb:cc:dd:ee:ff"
            echo ""
        else
            eval "$varname='$value'"
            return 0
        fi
    done
}

# Read yes/no confirmation
# Usage: read_confirm "prompt" "variable_name" ["default_y_or_n"]
read_confirm() {
    local prompt="$1"
    local varname="$2"
    local default="$3"
    local value=""
    
    while true; do
        if [ "$default" = "y" ]; then
            echo -e "${YELLOW}${prompt} (Y/n):${NC}"
        elif [ "$default" = "n" ]; then
            echo -e "${YELLOW}${prompt} (y/N):${NC}"
        else
            echo -e "${YELLOW}${prompt} (y/n):${NC}"
        fi
        read -p "> " value < /dev/tty
        
        # Use default if input is empty and default is provided
        if [ -z "$value" ] && [ -n "$default" ]; then
            value="$default"
        fi
        
        case "$value" in
            [Yy]|[Yy][Ee][Ss]) eval "$varname=true"; return 0 ;;
            [Nn]|[Nn][Oo]) eval "$varname=false"; return 0 ;;
            *) print_error "Please enter 'y' for yes or 'n' for no."; echo "" ;;
        esac
    done
}

# Read optional input - allows empty value
# Usage: read_optional "prompt" "variable_name" ["default_value"]
read_optional() {
    local prompt="$1"
    local varname="$2"
    local default="$3"
    local value=""
    
    if [ -n "$default" ]; then
        echo -e "${YELLOW}${prompt} [${default}]:${NC}"
    else
        echo -e "${YELLOW}${prompt} (optional):${NC}"
    fi
    read -p "> " value < /dev/tty
    
    # Use default if input is empty
    if [ -z "$value" ] && [ -n "$default" ]; then
        value="$default"
    fi
    
    eval "$varname='$value'"
}

#===============================================================================
# Multi-Tunnel Helper Functions
#===============================================================================

# Read and validate tunnel name
# Usage: read_tunnel_name "prompt" "variable_name" ["default_value"]
read_tunnel_name() {
    local prompt="$1"
    local varname="$2"
    local default="$3"
    local value=""
    local name_regex='^[a-z0-9][a-z0-9-]*$'
    
    while true; do
        if [ -n "$default" ]; then
            echo -e "${YELLOW}${prompt} [${default}]:${NC}"
        else
            echo -e "${YELLOW}${prompt}:${NC}"
        fi
        echo -e "${CYAN}(lowercase, alphanumeric and hyphens only, e.g., usa, germany, server-1)${NC}"
        read -p "> " value < /dev/tty
        
        # Use default if provided and input is empty
        if [ -z "$value" ] && [ -n "$default" ]; then
            value="$default"
        fi
        
        # Validate
        if [ -z "$value" ]; then
            print_error "Tunnel name is required."
            echo ""
        elif ! [[ "$value" =~ $name_regex ]]; then
            print_error "Invalid name. Use lowercase letters, numbers, and hyphens only."
            echo ""
        elif [ ${#value} -gt 32 ]; then
            print_error "Name too long. Maximum 32 characters."
            echo ""
        elif [ -f "$PAQET_DIR/config-${value}.yaml" ]; then
            print_error "Tunnel '$value' already exists. Choose a different name."
            echo ""
        else
            eval "$varname='$value'"
            return 0
        fi
    done
}

# Get list of all tunnel config files (legacy + named)
get_tunnel_configs() {
    # Legacy config first
    if [ -f "$PAQET_DIR/config.yaml" ]; then
        local role=$(grep "^role:" "$PAQET_DIR/config.yaml" 2>/dev/null | awk '{print $2}' | tr -d '"')
        # Only include legacy if it's a client config (Server A)
        # Server B configs are single-instance and don't need tunnel management
        if [ "$role" = "client" ]; then
            echo "$PAQET_DIR/config.yaml"
        fi
    fi
    # Named tunnel configs
    for f in "$PAQET_DIR"/config-*.yaml; do
        [ -f "$f" ] && echo "$f"
    done
    return 0
}

# Get ALL config files including server configs (for status/uninstall)
get_all_configs() {
    if [ -f "$PAQET_DIR/config.yaml" ]; then
        echo "$PAQET_DIR/config.yaml"
    fi
    for f in "$PAQET_DIR"/config-*.yaml; do
        [ -f "$f" ] && echo "$f"
    done
    return 0
}

# Extract tunnel name from config path
# Returns "default" for legacy config.yaml, or the name for config-<name>.yaml
get_tunnel_name() {
    local config_path="$1"
    local filename=$(basename "$config_path")
    if [ "$filename" = "config.yaml" ]; then
        echo "default"
    else
        echo "$filename" | sed 's/^config-//; s/\.yaml$//'
    fi
}

# Get service name for a tunnel
get_tunnel_service() {
    local config_path="$1"
    local name=$(get_tunnel_name "$config_path")
    if [ "$name" = "default" ]; then
        echo "paqet"
    else
        echo "paqet-${name}"
    fi
}

# Count total number of tunnel configs (client tunnels only)
get_tunnel_count() {
    local count=0
    local configs=$(get_tunnel_configs)
    if [ -n "$configs" ]; then
        count=$(echo "$configs" | wc -l)
    fi
    echo "$count"
}

# List all tunnels with status
list_tunnels() {
    local configs=$(get_all_configs)
    
    if [ -z "$configs" ]; then
        print_info "No tunnels configured"
        return 1
    fi
    
    local idx=0
    while IFS= read -r config_file; do
        idx=$((idx + 1))
        local name=$(get_tunnel_name "$config_file")
        local service=$(get_tunnel_service "$config_file")
        local role=$(grep "^role:" "$config_file" 2>/dev/null | awk '{print $2}' | tr -d '"')
        
        # Get status
        local status="${RED}Stopped${NC}"
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            status="${GREEN}Running${NC}"
        fi
        
        # Get details based on role
        local details=""
        if [ "$role" = "client" ]; then
            local server_addr=$(grep -A1 "^server:" "$config_file" 2>/dev/null | grep "addr:" | awk '{print $2}' | tr -d '"')
            local forward_ports=$(grep 'listen:' "$config_file" 2>/dev/null | grep -oE ':[0-9]+"' | tr -d ':"' | tr '\n' ',' | sed 's/,$//')
            details="-> ${server_addr}  ports: ${forward_ports}"
        elif [ "$role" = "server" ]; then
            local listen_addr=$(grep -A1 "^listen:" "$config_file" 2>/dev/null | grep "addr:" | awk '{print $2}' | tr -d '"')
            details="listening on ${listen_addr}"
        fi
        
        echo -e "  ${CYAN}${idx})${NC} ${YELLOW}${name}${NC} [${status}] (${role}) ${details}"
    done <<< "$configs"
}

# Select a tunnel interactively, sets PAQET_CONFIG and PAQET_SERVICE globals
# Returns 0 on success, 1 if no tunnels or user cancelled
select_tunnel() {
    local prompt="${1:-Select tunnel}"
    local configs=$(get_all_configs)
    local count=0
    if [ -n "$configs" ]; then
        count=$(echo "$configs" | wc -l)
    fi
    
    if [ -z "$configs" ] || [ "$count" -eq 0 ]; then
        print_error "No tunnels configured"
        return 1
    fi
    
    # If only one tunnel, auto-select it
    if [ "$count" -eq 1 ]; then
        local config_file=$(echo "$configs" | head -1)
        PAQET_CONFIG="$config_file"
        PAQET_SERVICE=$(get_tunnel_service "$config_file")
        local name=$(get_tunnel_name "$config_file")
        print_info "Using tunnel: $name"
        return 0
    fi
    
    # Multiple tunnels - show list and ask
    echo ""
    echo -e "${YELLOW}${prompt}:${NC}"
    echo ""
    list_tunnels
    echo ""
    
    read -p "Choice: " tunnel_choice < /dev/tty
    
    # Validate choice
    if ! [[ "$tunnel_choice" =~ ^[0-9]+$ ]] || [ "$tunnel_choice" -lt 1 ] || [ "$tunnel_choice" -gt "$count" ]; then
        print_error "Invalid choice"
        return 1
    fi
    
    local config_file=$(echo "$configs" | sed -n "${tunnel_choice}p")
    PAQET_CONFIG="$config_file"
    PAQET_SERVICE=$(get_tunnel_service "$config_file")
    local name=$(get_tunnel_name "$config_file")
    print_info "Selected tunnel: $name"
    return 0
}

#===============================================================================
# System Detection Functions
#===============================================================================

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run as root"
        exit 1
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS="rhel"
    else
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    fi
    echo "$OS"
}

detect_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64)  echo "amd64" ;;
        aarch64) echo "arm64" ;;
        armv7l)  echo "arm" ;;
        *)       echo "$arch" ;;
    esac
}

get_public_ip() {
    local ip=""
    ip=$(curl -4 -s --max-time 3 ifconfig.me 2>/dev/null) || \
    ip=$(curl -4 -s --max-time 3 icanhazip.com 2>/dev/null) || \
    ip=$(curl -4 -s --max-time 3 api.ipify.org 2>/dev/null) || \
    ip=$(hostname -I | awk '{print $1}')
    
    if echo "$ip" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        echo "$ip"
    else
        hostname -I | awk '{print $1}'
    fi
}

is_private_or_nonpublic_ipv4() {
    local ip="$1"
    # RFC1918 + loopback + link-local + CGNAT
    [[ "$ip" =~ ^10\. ]] && return 0
    [[ "$ip" =~ ^192\.168\. ]] && return 0
    [[ "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] && return 0
    [[ "$ip" =~ ^127\. ]] && return 0
    [[ "$ip" =~ ^169\.254\. ]] && return 0
    [[ "$ip" =~ ^100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\. ]] && return 0
    return 1
}

get_local_ip() {
    local interface=$1
    ip -4 addr show "$interface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1
}

get_default_interface() {
    ip route | grep default | awk '{print $5}' | head -1
}

get_gateway_ip() {
    ip route | grep default | awk '{print $3}' | head -1
}

get_gateway_mac() {
    local gateway_ip=$(get_gateway_ip)
    if [ -n "$gateway_ip" ]; then
        # Ping to populate neighbor cache
        ping -c 1 -W 1 "$gateway_ip" >/dev/null 2>&1 || true
        
        # Try ip neigh first (modern method)
        local mac=$(ip neigh show "$gateway_ip" 2>/dev/null | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | head -1)
        
        # Fallback to arp if ip neigh fails
        if [ -z "$mac" ] && command -v arp >/dev/null 2>&1; then
            mac=$(arp -n "$gateway_ip" 2>/dev/null | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | head -1)
        fi
        
        echo "$mac"
    fi
}

check_port_conflict() {
    local port=$1
    local pid=""
    
    if ss -tuln | grep -q ":${port} "; then
        print_warning "Port $port is already in use!"
        
        pid=$(lsof -t -i:$port 2>/dev/null | head -1)
        if [ -n "$pid" ]; then
            local pname=$(ps -p $pid -o comm= 2>/dev/null)
            echo -e "  Process: ${CYAN}$pname${NC} (PID: $pid)"
            echo ""
            echo -e "${YELLOW}Kill this process? (y/n)${NC}"
            read -p "> " kill_choice < /dev/tty
            
            if [[ "$kill_choice" =~ ^[Yy]$ ]]; then
                kill -9 $pid 2>/dev/null || true
                sleep 1
                pkill -9 -f ".*:${port}" 2>/dev/null || true
                print_success "Process killed"
            else
                print_error "Cannot continue with port in use. Please free the port or choose another."
                return 1
            fi
        fi
    fi
}

check_port_conflict_proto() {
    local port=$1
    local proto="${2:-tcp}"

    local ss_args="-tln"
    [ "$proto" = "udp" ] && ss_args="-uln"

    if ss $ss_args 2>/dev/null | grep -q ":${port} "; then
        print_warning "Port $port/$proto is already in use!"
        local pid=""
        pid=$(lsof -t -i${proto}:$port 2>/dev/null | head -1)
        if [ -n "$pid" ]; then
            local pname=$(ps -p $pid -o comm= 2>/dev/null)
            echo -e "  Process: ${CYAN}$pname${NC} (PID: $pid)"
        fi
        print_error "Please free the port or choose another."
        return 1
    fi
    return 0
}

#===============================================================================
# Installation Functions
#===============================================================================

# Iran server network optimization (DNS + apt mirror selection)
run_iran_optimizations() {
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}          Iran Server Network Optimization                  ${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}These scripts can help optimize your Iran server:${NC}"
    echo -e "  ${YELLOW}1.${NC} DNS Finder - Find the best DNS servers for Iran"
    echo -e "  ${YELLOW}2.${NC} Mirror Selector - Find the fastest apt repository mirror"
    echo ""
    echo -e "${CYAN}This can significantly improve download speeds and reliability.${NC}"
    echo ""
    
    read_confirm "Run network optimization scripts before installation?" run_optimize "y"
    
    if [ "$run_optimize" = true ]; then
        echo ""
        
        # Run DNS optimization
        print_step "Running DNS Finder..."
        print_info "This will find and configure the best DNS for Iran"
        echo ""
        if bash <(curl -Ls https://github.com/alinezamifar/IranDNSFinder/raw/refs/heads/main/dns.sh); then
            print_success "DNS optimization completed"
        else
            print_warning "DNS optimization failed or was skipped"
        fi
        
        echo ""
        
        # Run apt mirror optimization (only for Debian/Ubuntu)
        local os=$(detect_os)
        if [[ "$os" == "ubuntu" ]] || [[ "$os" == "debian" ]]; then
            print_step "Running Ubuntu/Debian Mirror Selector..."
            print_info "This will find the fastest apt repository mirror"
            echo ""
            if bash <(curl -Ls https://github.com/alinezamifar/DetectUbuntuMirror/raw/refs/heads/main/DUM.sh); then
                print_success "Mirror optimization completed"
            else
                print_warning "Mirror optimization failed or was skipped"
            fi
        else
            print_info "Mirror selector is only available for Ubuntu/Debian"
        fi
        
        echo ""
        print_success "Network optimization completed!"
        echo ""
    else
        print_info "Skipping network optimization"
    fi
}

install_dependencies() {
    print_step "Installing dependencies..."
    
    echo -e "${YELLOW}Install dependencies? (y/n/s to skip)${NC}"
    echo -e "${CYAN}Required: libpcap-dev, iptables, curl${NC}"
    read -t 10 -p "> " install_deps < /dev/tty || install_deps="y"
    
    if [[ "$install_deps" =~ ^[Ss]$ ]]; then
        print_warning "Skipping dependency installation"
        print_info "Make sure these are installed: libpcap-dev iptables curl"
        return 0
    fi
    
    if [[ ! "$install_deps" =~ ^[Yy]$ ]] && [ -n "$install_deps" ]; then
        print_warning "Skipping dependency installation"
        return 0
    fi
    
    local os=$(detect_os)
    case $os in
        ubuntu|debian)
            print_info "Running apt update (may take time)..."
            timeout 30 apt update -qq 2>/dev/null || {
                print_warning "apt update timed out or failed"
                print_info "Continuing anyway..."
            }
            
            print_info "Installing packages..."
            apt install -y -qq curl wget libpcap-dev iptables lsof > /dev/null 2>&1 || {
                print_warning "Some packages may have failed to install"
                print_info "Continuing anyway..."
            }
            ;;
        centos|rhel|fedora|rocky|almalinux)
            yum install -y -q curl wget libpcap-devel iptables lsof > /dev/null 2>&1 || {
                print_warning "Some packages may have failed to install"
            }
            ;;
        *)
            print_warning "Unknown OS. Please install libpcap manually."
            ;;
    esac
    
    print_success "Dependency installation completed"
}

PAQET_DL_PROVIDER=""
PAQET_DL_VERSION=""
PAQET_DL_ARCHIVE_NAME=""
PAQET_DL_URL=""
PAQET_DL_RELEASE_PAGE=""

get_latest_paqet_release_tag_for_provider() {
    local provider="${1:-$(get_current_core_provider)}"
    case "$provider" in
        official)
            curl -s --max-time 10 "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" 2>/dev/null \
                | grep '"tag_name"' | head -1 | sed -E 's/.*"([^"]+)".*/\1/'
            ;;
        behzad-optimized)
            echo "$OPTIMIZED_CORE_RELEASE_TAG"
            ;;
        *)
            echo ""
            ;;
    esac
}

resolve_behzad_optimized_asset() {
    local arch="$1"
    local api_url="https://api.github.com/repos/${OPTIMIZED_CORE_RELEASE_REPO}/releases/tags/${OPTIMIZED_CORE_RELEASE_TAG}"
    local api_json=""
    api_json=$(curl -s --max-time 15 "$api_url" 2>/dev/null)

    if [ -z "$api_json" ]; then
        print_error "Failed to fetch optimized release metadata"
        print_info "Check connectivity to GitHub API or try again later"
        return 1
    fi

    local supported_arch=""
    case "$arch" in
        amd64|arm64) supported_arch="$arch" ;;
        *)
            print_error "Optimized core is not available for architecture: $arch"
            print_info "Supported optimized core architectures currently: amd64, arm64"
            return 1
            ;;
    esac

    local asset_pair=""
    asset_pair=$(printf '%s\n' "$api_json" | awk -v target_arch="$supported_arch" '
        BEGIN { current_name="" }
        /"name"[[:space:]]*:/ {
            line=$0
            sub(/^.*"name"[[:space:]]*:[[:space:]]*"/, "", line)
            sub(/".*$/, "", line)
            current_name=line
        }
        /"browser_download_url"[[:space:]]*:/ {
            line=$0
            sub(/^.*"browser_download_url"[[:space:]]*:[[:space:]]*"/, "", line)
            sub(/".*$/, "", line)
            if (current_name ~ /paqet/ && current_name ~ /tar\.gz/ && current_name ~ target_arch) {
                print current_name "|" line
                exit
            }
        }
    ')

    if [ -z "$asset_pair" ] || [[ "$asset_pair" != *"|"* ]]; then
        print_error "Could not locate optimized core asset for architecture: $supported_arch"
        print_info "Release page: https://github.com/${OPTIMIZED_CORE_RELEASE_REPO}/releases/tag/${OPTIMIZED_CORE_RELEASE_TAG}"
        return 1
    fi

    PAQET_DL_PROVIDER="behzad-optimized"
    PAQET_DL_VERSION=$(echo "$api_json" | grep '"tag_name"' | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
    [ -z "$PAQET_DL_VERSION" ] && PAQET_DL_VERSION="$OPTIMIZED_CORE_RELEASE_TAG"
    PAQET_DL_ARCHIVE_NAME="${asset_pair%%|*}"
    PAQET_DL_URL="${asset_pair#*|}"
    PAQET_DL_RELEASE_PAGE="https://github.com/${OPTIMIZED_CORE_RELEASE_REPO}/releases/tag/${OPTIMIZED_CORE_RELEASE_TAG}"
    return 0
}

resolve_paqet_download_source() {
    local provider="${1:-$(get_current_core_provider)}"
    local arch="$2"
    local os="${3:-linux}"

    PAQET_DL_PROVIDER=""
    PAQET_DL_VERSION=""
    PAQET_DL_ARCHIVE_NAME=""
    PAQET_DL_URL=""
    PAQET_DL_RELEASE_PAGE=""

    case "$provider" in
        official)
            local version=""
            if [ "$PAQET_VERSION" = "latest" ]; then
                version=$(get_latest_paqet_release_tag_for_provider official)
                if [ -z "$version" ]; then
                    print_warning "Failed to get latest version from GitHub"
                    version="v1.0.0-alpha.11"  # Fallback version
                fi
            else
                version="$PAQET_VERSION"
            fi

            PAQET_DL_PROVIDER="official"
            PAQET_DL_VERSION="$version"
            PAQET_DL_ARCHIVE_NAME="paqet-${os}-${arch}-${version}.tar.gz"
            PAQET_DL_URL="https://github.com/${GITHUB_REPO}/releases/download/${version}/${PAQET_DL_ARCHIVE_NAME}"
            PAQET_DL_RELEASE_PAGE="https://github.com/${GITHUB_REPO}/releases"
            ;;
        behzad-optimized)
            resolve_behzad_optimized_asset "$arch" || return 1
            ;;
        *)
            print_error "Unknown core provider: $provider"
            return 1
            ;;
    esac
    return 0
}

download_paqet() {
    print_step "Downloading paqet binary..."
    
    local arch=$(detect_arch)
    local os="linux"
    local provider
    provider=$(get_current_core_provider)
    
    mkdir -p "$PAQET_DIR"

    if ! resolve_paqet_download_source "$provider" "$arch" "$os"; then
        return 1
    fi

    local version="$PAQET_DL_VERSION"
    local archive_name="$PAQET_DL_ARCHIVE_NAME"
    local download_url="$PAQET_DL_URL"
    local cache_archive=""
    cache_archive=$(get_paqet_core_archive_cache_path "$PAQET_DL_PROVIDER" "$version" "$archive_name")

    print_info "Core provider: $(get_core_provider_label "$provider")"
    print_info "Downloading version/tag: $version"
    print_info "URL: $download_url"
    
    # Check for local file in /root/paqet first
    local local_dir="/root/paqet"
    local local_archive="$local_dir/$archive_name"
    
    # Download and extract
    local temp_archive="/tmp/paqet.tar.gz"
    local download_success=false
    local archive_source=""
    local should_cache_archive=false
    
    if [ -f "$cache_archive" ]; then
        print_success "Using cached core archive: $cache_archive"
        cp "$cache_archive" "$temp_archive"
        download_success=true
        archive_source="cache"
    elif [ -f "$local_archive" ]; then
        print_success "Found local file: $local_archive"
        cp "$local_archive" "$temp_archive"
        download_success=true
        archive_source="local-exact"
    elif [ -d "$local_dir" ] && [ "$(ls -A $local_dir/*.tar.gz 2>/dev/null)" ]; then
        # Found some tar.gz in /root/paqet, ask user
        print_info "Found archives in $local_dir:"
        ls -1 "$local_dir"/*.tar.gz 2>/dev/null
        echo ""
        echo -e "${YELLOW}Use one of these files? (y/n)${NC}"
        read -p "> " use_local < /dev/tty
        
        if [[ "$use_local" =~ ^[Yy]$ ]]; then
            while true; do
                echo -e "${YELLOW}Enter the filename (or full path). Press Enter to cancel:${NC}"
                read -p "> " user_file < /dev/tty
                [ -z "$user_file" ] && break
                if [ -f "$user_file" ]; then
                    local_archive="$user_file"
                    cp "$local_archive" "$temp_archive"
                    download_success=true
                    archive_source="local-manual"
                    print_success "Using local file: $local_archive"
                    break
                elif [ -f "$local_dir/$user_file" ]; then
                    local_archive="$local_dir/$user_file"
                    cp "$local_archive" "$temp_archive"
                    download_success=true
                    archive_source="local-manual"
                    print_success "Using local file: $local_archive"
                    break
                else
                    print_error "File not found: $user_file. Try again or press Enter to cancel."
                fi
            done
        fi
    fi
    
    # Try downloading if no local file was used
    if [ "$download_success" = false ]; then
        print_info "Attempting download..."
        if timeout 30 curl -fsSL "$download_url" -o "$temp_archive" 2>/dev/null; then
            download_success=true
            archive_source="download"
            print_success "Download completed"
        else
            print_error "Failed to download paqet binary"
            print_warning "Download blocked or network issue detected"
            echo ""
            echo -e "${YELLOW}Do you have a local copy of the paqet archive? (y/n)${NC}"
            read -p "> " has_local < /dev/tty
            
            if [[ "$has_local" =~ ^[Yy]$ ]]; then
                while true; do
                    echo -e "${YELLOW}Enter the full path to the paqet tar.gz file. Press Enter to cancel:${NC}"
                    echo -e "${CYAN}Example: /root/paqet/${archive_name}${NC}"
                    read -p "> " local_archive < /dev/tty
                    [ -z "$local_archive" ] && break
                    if [ -f "$local_archive" ]; then
                        cp "$local_archive" "$temp_archive"
                        download_success=true
                        archive_source="local-manual"
                        print_success "Using local file: $local_archive"
                        break
                    else
                        print_error "File not found: $local_archive. Try again or press Enter to cancel."
                    fi
                done
            fi
            if [ "$download_success" = false ]; then
                print_info "Please download manually from: ${PAQET_DL_RELEASE_PAGE:-https://github.com/${GITHUB_REPO}/releases}"
                print_info "Save to: $local_dir/"
                print_info "Then run this installer again (you will return to the main menu now)."
                return 1
            fi
        fi
    fi

    if [ "$download_success" = true ] && [ "$archive_source" != "cache" ]; then
        should_cache_archive=true
    fi
    
    if [ "$download_success" = true ]; then
        # Extract into a temp directory first (more robust to upstream archive layout changes)
        local temp_extract_dir=""
        temp_extract_dir=$(mktemp -d /tmp/paqet-extract.XXXXXX 2>/dev/null || true)
        [ -z "$temp_extract_dir" ] && temp_extract_dir="/tmp/paqet-extract.$$"
        mkdir -p "$temp_extract_dir"

        tar -xzf "$temp_archive" -C "$temp_extract_dir" 2>/dev/null || {
            print_error "Failed to extract archive"
            rm -rf "$temp_extract_dir" 2>/dev/null || true
            rm -f "$temp_archive"
            return 1
        }

        # Try known/expected names first, then fall back to auto-detection
        local extracted_binary=""
        local candidate=""
        for candidate in \
            "$temp_extract_dir/paqet_${os}_${arch}" \
            "$temp_extract_dir/paqet" \
            "$temp_extract_dir/paqet-${os}-${arch}" \
            "$temp_extract_dir/paqet_${arch}" \
            "$temp_extract_dir/paqet-${arch}"; do
            if [ -f "$candidate" ]; then
                extracted_binary="$candidate"
                break
            fi
        done

        if [ -z "$extracted_binary" ]; then
            extracted_binary=$(find "$temp_extract_dir" -type f \( -name 'paqet' -o -name 'paqet_*' -o -name 'paqet-*' \) \
                ! -name '*.tar.gz' ! -name '*.txt' ! -name '*.md' | head -n 1)
        fi

        if [ -n "$extracted_binary" ] && [ -f "$extracted_binary" ]; then
            mv "$extracted_binary" "$PAQET_BIN"
            chmod +x "$PAQET_BIN"
            if [ "$should_cache_archive" = true ]; then
                mkdir -p "$(dirname "$cache_archive")" 2>/dev/null || true
                if cp "$temp_archive" "$cache_archive" 2>/dev/null; then
                    print_info "Cached core archive: $cache_archive"
                else
                    print_warning "Could not save core archive to cache (continuing)"
                fi
            fi
            set_installed_core_metadata "$PAQET_DL_PROVIDER" "$version" "$archive_name"
            rm -rf "$temp_extract_dir" 2>/dev/null || true
            rm -f "$temp_archive"
            print_success "paqet binary installed successfully"
        else
            print_error "Binary not found in archive"
            print_info "Archive contents (top level):"
            ls -la "$temp_extract_dir" 2>/dev/null || true
            rm -rf "$temp_extract_dir" 2>/dev/null || true
            rm -f "$temp_archive"
            return 1
        fi
    fi
    if [ "$download_success" != true ]; then
        return 1
    fi
}

generate_secret_key() {
    # Generate a random 32-character key
    if command -v openssl &> /dev/null; then
        openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 32
    else
        cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 32
    fi
}

setup_iptables() {
    local port=$1
    print_step "Configuring iptables for port $port..."
    
    # Remove existing rules if any
    iptables -t raw -D PREROUTING -p tcp --dport $port -j NOTRACK 2>/dev/null || true
    iptables -t raw -D OUTPUT -p tcp --sport $port -j NOTRACK 2>/dev/null || true
    iptables -t mangle -D OUTPUT -p tcp --sport $port --tcp-flags RST RST -j DROP 2>/dev/null || true
    iptables -t mangle -D PREROUTING -p tcp --dport $port --tcp-flags RST RST -j DROP 2>/dev/null || true
    
    # Add new rules
    iptables -t raw -A PREROUTING -p tcp --dport $port -j NOTRACK
    iptables -t raw -A OUTPUT -p tcp --sport $port -j NOTRACK
    # Block outgoing RST from kernel (prevents kernel interference with raw sockets)
    iptables -t mangle -A OUTPUT -p tcp --sport $port --tcp-flags RST RST -j DROP
    # Block incoming fake RST packets (some ISPs inject spoofed RSTs to kill tunnels)
    iptables -t mangle -A PREROUTING -p tcp --dport $port --tcp-flags RST RST -j DROP
    
    save_iptables
    print_success "iptables configured"
}

# Setup iptables for Server A (client) - targets Server B's IP:port
# Server A uses ephemeral ports, so rules must match by destination (Server B)
setup_iptables_client() {
    local server_ip=$1
    local server_port=$2
    print_step "Configuring iptables for tunnel to $server_ip:$server_port..."
    
    # Remove existing rules if any
    iptables -t raw -D OUTPUT -p tcp -d $server_ip --dport $server_port -j NOTRACK 2>/dev/null || true
    iptables -t raw -D PREROUTING -p tcp -s $server_ip --sport $server_port -j NOTRACK 2>/dev/null || true
    iptables -t mangle -D OUTPUT -p tcp -d $server_ip --dport $server_port --tcp-flags RST RST -j DROP 2>/dev/null || true
    iptables -t mangle -D PREROUTING -p tcp -s $server_ip --sport $server_port --tcp-flags RST RST -j DROP 2>/dev/null || true
    
    # Bypass kernel connection tracking for tunnel traffic
    iptables -t raw -A OUTPUT -p tcp -d $server_ip --dport $server_port -j NOTRACK
    iptables -t raw -A PREROUTING -p tcp -s $server_ip --sport $server_port -j NOTRACK
    # Block outgoing RST from kernel to Server B (prevents kernel from killing raw socket connections)
    iptables -t mangle -A OUTPUT -p tcp -d $server_ip --dport $server_port --tcp-flags RST RST -j DROP
    # Block incoming fake RST from middleboxes (ISPs inject spoofed RSTs appearing to come from Server B)
    iptables -t mangle -A PREROUTING -p tcp -s $server_ip --sport $server_port --tcp-flags RST RST -j DROP
    
    save_iptables
    print_success "iptables configured (connection protection rules active)"
}

# Remove iptables client rules for a specific Server B target
remove_iptables_client() {
    local server_ip=$1
    local server_port=$2
    iptables -t raw -D OUTPUT -p tcp -d $server_ip --dport $server_port -j NOTRACK 2>/dev/null || true
    iptables -t raw -D PREROUTING -p tcp -s $server_ip --sport $server_port -j NOTRACK 2>/dev/null || true
    iptables -t mangle -D OUTPUT -p tcp -d $server_ip --dport $server_port --tcp-flags RST RST -j DROP 2>/dev/null || true
    iptables -t mangle -D PREROUTING -p tcp -s $server_ip --sport $server_port --tcp-flags RST RST -j DROP 2>/dev/null || true
}

# Save iptables rules to persistent storage
save_iptables() {
    if command -v iptables-save &> /dev/null; then
        if [ -d /etc/iptables ]; then
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
        elif [ -f /etc/sysconfig/iptables ]; then
            iptables-save > /etc/sysconfig/iptables 2>/dev/null || true
        fi
    fi
}

#===============================================================================
# IPTables NAT Port Forwarding
# Kernel-level port forwarding via iptables NAT rules.
# Useful for independently managing which ports go to which destination,
# testing backup tunnels without service restarts, and relay setups.
#===============================================================================

ensure_ip_forwarding() {
    local current=$(sysctl -n net.ipv4.ip_forward 2>/dev/null)
    if [ "$current" != "1" ]; then
        print_step "Enabling IP forwarding..."
        echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/30-ip_forward.conf
        sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1
        sysctl --system > /dev/null 2>&1
        print_success "IP forwarding enabled"
    fi
}

add_nat_forward_multi_port() {
    echo ""
    echo -e "${YELLOW}Multi-Port NAT Forward${NC}"
    echo -e "${CYAN}Forward specific ports (TCP+UDP) to a destination server via iptables NAT${NC}"
    echo ""
    
    local dest_ip
    while true; do
        echo -e "${YELLOW}Enter destination server IP (e.g. 1.2.3.4). Press Enter to cancel:${NC}"
        read -p "> " dest_ip < /dev/tty
        [ -z "$dest_ip" ] && { print_info "Cancelled."; return 0; }
        if [[ "$dest_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            break
        fi
        print_error "Invalid IP address format. Try again or press Enter to cancel."
    done
    
    local ports
    while true; do
        echo -e "${YELLOW}Enter ports to forward (comma-separated, e.g. 443,8443,2053). Press Enter to cancel:${NC}"
        read -p "> " ports < /dev/tty
        [ -z "$ports" ] && { print_info "Cancelled."; return 0; }
        ports=$(echo "$ports" | tr -d ' ')
        if [[ "$ports" =~ ^[0-9]+(,[0-9]+)*$ ]]; then
            break
        fi
        print_error "Invalid port format. Use comma-separated numbers (e.g. 443,8443). Try again or press Enter to cancel."
    done
    
    ensure_ip_forwarding
    
    print_step "Adding NAT forwarding rules: ports $ports -> $dest_ip ..."
    
    # TCP
    iptables -t nat -A PREROUTING -p tcp --match multiport --dports $ports -j DNAT --to-destination $dest_ip
    iptables -t nat -A POSTROUTING -p tcp --match multiport --dports $ports -j MASQUERADE
    # UDP
    iptables -t nat -A PREROUTING -p udp --match multiport --dports $ports -j DNAT --to-destination $dest_ip
    iptables -t nat -A POSTROUTING -p udp --match multiport --dports $ports -j MASQUERADE
    
    save_iptables
    print_success "NAT forwarding added: ports $ports -> $dest_ip (TCP+UDP)"
}

add_nat_forward_all_ports() {
    echo ""
    echo -e "${YELLOW}All-Ports NAT Forward${NC}"
    echo -e "${CYAN}Forward ALL ports to a destination, except specified exclusions${NC}"
    echo ""
    
    local relay_ip
    while true; do
        echo -e "${YELLOW}Enter THIS server's IP (relay IP). Press Enter to cancel:${NC}"
        read -p "> " relay_ip < /dev/tty
        [ -z "$relay_ip" ] && { print_info "Cancelled."; return 0; }
        if [[ "$relay_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            break
        fi
        print_error "Invalid IP address format. Try again or press Enter to cancel."
    done
    
    local dest_ip
    while true; do
        echo -e "${YELLOW}Enter destination server IP. Press Enter to cancel:${NC}"
        read -p "> " dest_ip < /dev/tty
        [ -z "$dest_ip" ] && { print_info "Cancelled."; return 0; }
        if [[ "$dest_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            break
        fi
        print_error "Invalid IP address format. Try again or press Enter to cancel."
    done
    
    local exclude_ports
    while true; do
        echo -e "${YELLOW}Enter ports to EXCLUDE (comma-separated, e.g. 22,80). Press Enter to cancel:${NC}"
        read -p "> " exclude_ports < /dev/tty
        [ -z "$exclude_ports" ] && { print_info "Cancelled."; return 0; }
        exclude_ports=$(echo "$exclude_ports" | tr -d ' ')
        if [[ "$exclude_ports" =~ ^[0-9]+(,[0-9]+)*$ ]]; then
            break
        fi
        print_error "Invalid port format. Use comma-separated numbers (e.g. 22,80). Try again or press Enter to cancel."
    done
    
    # Warn about SSH
    if ! echo ",$exclude_ports," | grep -q ",22,"; then
        print_warning "Port 22 (SSH) is NOT in your exclusion list!"
        echo -e "${RED}You may lose SSH access if port 22 is forwarded.${NC}"
        read_confirm "Continue without excluding port 22?" skip_ssh_warn "n"
        if [ "$skip_ssh_warn" != true ]; then
            print_info "Cancelled. Add port 22 to your exclusion list."
            return 1
        fi
    fi
    
    ensure_ip_forwarding
    
    print_step "Adding all-ports NAT forwarding to $dest_ip (excluding $exclude_ports)..."
    
    # First: redirect excluded ports back to this server (keeps them local)
    iptables -t nat -A PREROUTING -p tcp --match multiport --dports $exclude_ports -j DNAT --to-destination $relay_ip
    iptables -t nat -A PREROUTING -p udp --match multiport --dports $exclude_ports -j DNAT --to-destination $relay_ip
    # Then: catch-all forward everything else to destination
    iptables -t nat -A PREROUTING -p tcp -j DNAT --to-destination $dest_ip
    iptables -t nat -A PREROUTING -p udp -j DNAT --to-destination $dest_ip
    iptables -t nat -A POSTROUTING -j MASQUERADE
    
    save_iptables
    print_success "All-ports NAT forwarding added to $dest_ip (excluding $exclude_ports)"
}

view_nat_rules() {
    echo ""
    echo -e "${YELLOW}Current NAT Table Rules:${NC}"
    echo -e "${GREEN}─────────────────────────────────────────────────────────────${NC}"
    iptables -t nat -L -v --line-numbers 2>/dev/null || print_error "Failed to read NAT rules"
    echo -e "${GREEN}─────────────────────────────────────────────────────────────${NC}"
}

remove_nat_forward_by_dest() {
    echo ""
    echo -e "${YELLOW}Remove NAT Forwarding Rules by Destination${NC}"
    echo ""
    
    view_nat_rules
    echo ""
    
    echo -e "${YELLOW}Enter destination IP to remove rules for. Press Enter to cancel:${NC}"
    read -p "> " dest_ip < /dev/tty
    if [ -z "$dest_ip" ]; then
        print_info "Cancelled."
        return 0
    fi
    
    print_step "Removing NAT rules targeting $dest_ip..."
    
    local removed=0
    
    # Remove PREROUTING rules targeting this IP (reverse order to preserve line numbers)
    local pre_rules
    pre_rules=$(iptables -t nat -L PREROUTING --line-numbers -n 2>/dev/null | grep "to:${dest_ip}" | awk '{print $1}' | sort -rn)
    for num in $pre_rules; do
        iptables -t nat -D PREROUTING $num 2>/dev/null && removed=$((removed + 1))
    done
    
    # Remove POSTROUTING rules that reference this IP (if any)
    local post_rules
    post_rules=$(iptables -t nat -L POSTROUTING --line-numbers -n 2>/dev/null | grep "to:${dest_ip}" | awk '{print $1}' | sort -rn)
    for num in $post_rules; do
        iptables -t nat -D POSTROUTING $num 2>/dev/null && removed=$((removed + 1))
    done
    
    if [ $removed -gt 0 ]; then
        save_iptables
        print_success "Removed $removed NAT rule(s) targeting $dest_ip"
        print_info "POSTROUTING MASQUERADE rules (which don't reference a specific IP) may remain."
        print_info "Use 'View NAT Rules' to verify, or 'Flush All' for a clean slate."
    else
        print_warning "No NAT rules found targeting $dest_ip"
    fi
}

flush_nat_rules() {
    echo ""
    echo -e "${RED}WARNING: This will flush ALL iptables NAT rules!${NC}"
    echo -e "${YELLOW}Connection protection rules (raw/mangle) will NOT be affected.${NC}"
    echo ""
    
    read_confirm "Flush all NAT rules?" do_flush "n"
    
    if [ "$do_flush" = true ]; then
        print_step "Flushing NAT table..."
        iptables -t nat -F
        iptables -t nat -X 2>/dev/null || true
        
        save_iptables
        print_success "All NAT rules flushed"
        
        echo ""
        read_confirm "Also disable IP forwarding?" disable_fwd "n"
        if [ "$disable_fwd" = true ]; then
            echo "net.ipv4.ip_forward=0" > /etc/sysctl.d/30-ip_forward.conf
            sysctl -w net.ipv4.ip_forward=0 > /dev/null 2>&1
            sysctl --system > /dev/null 2>&1
            print_success "IP forwarding disabled"
        fi
    else
        print_info "Flush cancelled"
    fi
}

create_systemd_service() {
    print_step "Creating systemd service..."
    
    cat > /etc/systemd/system/${PAQET_SERVICE}.service << EOF
[Unit]
Description=paqet Raw Packet Tunnel
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
ExecStart=${PAQET_BIN} run -c ${PAQET_CONFIG}
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    print_success "Systemd service created"
}

#===============================================================================
# Server B Setup (Abroad - VPN Server with paqet server)
#===============================================================================

setup_server_b() {
    print_banner
    echo -e "${GREEN}Setting up Server B (Abroad - VPN Server)${NC}"
    echo -e "${CYAN}This server runs your V2Ray/X-UI and the paqet server${NC}"
    echo ""
    
    # Detect network configuration
    local interface=$(get_default_interface)
    local local_ip=$(get_local_ip "$interface")
    local public_ip=$(get_public_ip)
    local gateway_mac=$(get_gateway_mac)
    
    echo -e "${YELLOW}Network Configuration Detected:${NC}"
    echo -e "  Interface:   ${CYAN}$interface${NC}"
    echo -e "  Local IP:    ${CYAN}$local_ip${NC}"
    echo -e "  Public IP:   ${CYAN}$public_ip${NC}"
    echo -e "  Gateway MAC: ${CYAN}$gateway_mac${NC}"
    echo ""
    
    # Confirm or modify interface (with validation)
    read_required "Network interface" interface "$interface"
    
    # Get local IP for that interface (with validation)
    local_ip=$(get_local_ip "$interface")
    if [ -z "$local_ip" ]; then
        read_ip "Could not detect IP. Enter local IP" local_ip
    else
        read_optional "Local IP" local_ip "$local_ip"
    fi
    
    # Confirm gateway MAC (with validation)
    if [ -z "$gateway_mac" ]; then
        read_mac "Could not detect gateway MAC. Enter gateway MAC address" gateway_mac
    else
        read_optional "Gateway MAC" input_mac "$gateway_mac"
        [ -n "$input_mac" ] && gateway_mac="$input_mac"
    fi
    
    # paqet listen port (with validation)
    echo ""
    echo -e "${CYAN}Enter paqet listen port (for tunnel, NOT your V2Ray ports)${NC}"
    read_port "paqet listen port" PAQET_PORT "$DEFAULT_PAQET_PORT"
    
    # Check port conflict
    check_port_conflict "$PAQET_PORT" || return 0
    
    # Backend service ports (informational only; not stored in paqet server config)
    echo ""
    echo -e "${CYAN}These are the backend service ports on Server B (V2Ray/X-UI/WireGuard/Hysteria)${NC}"
    echo -e "${YELLOW}Informational only:${NC} this is shown in the final summary and is ${YELLOW}not${NC} written into the paqet server config."
    read_ports "Enter backend service ports (comma-separated)" INBOUND_PORTS "$DEFAULT_FORWARD_PORTS"
    
    # Generate or input secret key
    echo ""
    local secret_key=$(generate_secret_key)
    echo -e "${CYAN}Generated secret key: $secret_key${NC}"
    read_required "Secret key (press Enter to use generated)" secret_key "$secret_key"

    # PaqX-style automatic profile (CPU/RAM-aware)
    echo ""
    calculate_auto_kcp_profile
    show_auto_kcp_profile
    
    # Download paqet
    download_paqet || return 0
    
    # Setup iptables
    setup_iptables "$PAQET_PORT"
    apply_paqx_kernel_optimizations
    
    # Create config file
    print_step "Creating configuration..."

    local profile_network_pcap_fragment=""
    local profile_transport_buf_fragment=""
    local profile_kcp_extra_fragment=""
    local profile_conn_value=""
    local profile_kcp_block=""
    local profile_kcp_mtu=""
    build_profile_network_pcap_fragment "server" profile_network_pcap_fragment
    build_profile_transport_buffer_fragment profile_transport_buf_fragment
    build_profile_kcp_extra_fragment profile_kcp_extra_fragment
    profile_conn_value=$(get_effective_profile_conn_value)
    profile_kcp_block=$(get_effective_profile_kcp_block)
    profile_kcp_mtu=$(get_effective_profile_kcp_mtu)
    
    cat > "$PAQET_CONFIG" << EOF
# paqet Server Configuration
# Generated by installer on $(date)
role: "server"

log:
  level: "info"

listen:
  addr: ":${PAQET_PORT}"

network:
  interface: "${interface}"
  ipv4:
    addr: "${local_ip}:${PAQET_PORT}"
    router_mac: "${gateway_mac}"
  tcp:
    local_flag: ["PA"]
${profile_network_pcap_fragment}

transport:
  protocol: "kcp"${profile_transport_buf_fragment}
  conn: ${profile_conn_value}
  kcp:
    mode: "${DEFAULT_KCP_MODE}"
    key: "${secret_key}"
    mtu: ${profile_kcp_mtu}
    block: "${profile_kcp_block}"
${profile_kcp_extra_fragment}
EOF
    
    print_success "Configuration created"
    
    # Create systemd service
    create_systemd_service
    
    # Start service
    systemctl enable --now $PAQET_SERVICE
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                 Server B Ready!                            ${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${YELLOW}Public IP:${NC}     ${CYAN}$public_ip${NC}"
    echo -e "  ${YELLOW}paqet Port:${NC}    ${CYAN}$PAQET_PORT${NC}"
    echo -e "  ${YELLOW}V2Ray Ports:${NC}   ${CYAN}$INBOUND_PORTS${NC}"
    echo ""
    echo -e "${YELLOW}Secret Key (save this for Server A):${NC}"
    echo -e "${CYAN}$secret_key${NC}"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo -e "  1. Make sure V2Ray/X-UI is running on ports: ${CYAN}$INBOUND_PORTS${NC}"
    echo -e "  2. Run this installer on Server A with same secret key"
    echo -e "  3. Open port ${CYAN}$PAQET_PORT${NC} in cloud firewall (if any)"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo -e "  Status:  ${CYAN}systemctl status $PAQET_SERVICE${NC}"
    echo -e "  Logs:    ${CYAN}journalctl -u $PAQET_SERVICE -f${NC}"
    echo -e "  Restart: ${CYAN}systemctl restart $PAQET_SERVICE${NC}"
    echo ""
}

#===============================================================================
# Server A Setup (Entry Point - paqet client with port forwarding)
#===============================================================================

setup_server_a() {
    print_banner
    echo -e "${GREEN}Setting up Server A (Entry Point)${NC}"
    echo -e "${CYAN}This server accepts client connections and tunnels to Server B${NC}"
    echo ""
    
    # Ask for tunnel name
    echo -e "${CYAN}Each tunnel needs a unique name to identify the Server B it connects to.${NC}"
    echo -e "${CYAN}Examples: usa, germany, server-1${NC}"
    echo ""
    read_tunnel_name "Enter tunnel name" TUNNEL_NAME
    
    # Set per-tunnel config and service paths
    PAQET_CONFIG="$PAQET_DIR/config-${TUNNEL_NAME}.yaml"
    PAQET_SERVICE="paqet-${TUNNEL_NAME}"
    
    echo ""
    print_info "Tunnel '${TUNNEL_NAME}' will use:"
    echo -e "  Config:  ${CYAN}$PAQET_CONFIG${NC}"
    echo -e "  Service: ${CYAN}$PAQET_SERVICE${NC}"
    echo ""
    
    # Detect network configuration
    local interface=$(get_default_interface)
    local local_ip=$(get_local_ip "$interface")
    local public_ip=$(get_public_ip)
    local advertised_host="$public_ip"
    local gateway_mac=$(get_gateway_mac)
    
    echo -e "${YELLOW}Network Configuration Detected:${NC}"
    echo -e "  Interface:   ${CYAN}$interface${NC}"
    echo -e "  Local IP:    ${CYAN}$local_ip${NC}"
    echo -e "  Public IP:   ${CYAN}$public_ip${NC}"
    echo -e "  Gateway MAC: ${CYAN}$gateway_mac${NC}"
    echo ""

    if is_private_or_nonpublic_ipv4 "$public_ip"; then
        print_warning "Detected a private/non-public IP for this server ($public_ip)."
        print_info "This does NOT break the paqet tunnel to Server B (outbound tunnel can still work)."
        print_info "If clients connect from outside your LAN, use your router WAN IP / DDNS and port forwarding."
        echo ""
        read_optional "Advertised client IP/hostname for examples (optional)" advertised_override
        [ -n "$advertised_override" ] && advertised_host="$advertised_override"
        echo ""
    fi
    
    # Get Server B details (with validation - keeps asking until valid)
    echo -e "${CYAN}Enter Server B (Abroad) connection details for tunnel '${TUNNEL_NAME}'${NC}"
    read_ip "Server B public IP address" SERVER_B_IP
    
    echo ""
    read_port "paqet port on Server B" SERVER_B_PORT "$DEFAULT_PAQET_PORT"
    
    echo ""
    read_required "Secret key (from Server B setup)" SECRET_KEY
    
    # Confirm or modify interface (with validation)
    echo ""
    read_required "Network interface" interface "$interface"
    
    # Get local IP for that interface (with validation)
    local_ip=$(get_local_ip "$interface")
    if [ -z "$local_ip" ]; then
        read_ip "Could not detect IP. Enter local IP" local_ip
    else
        read_optional "Local IP" local_ip "$local_ip"
    fi
    
    # Confirm gateway MAC (with validation)
    if [ -z "$gateway_mac" ]; then
        read_mac "Could not detect gateway MAC. Enter gateway MAC address" gateway_mac
    else
        read_optional "Gateway MAC" input_mac "$gateway_mac"
        [ -n "$input_mac" ] && gateway_mac="$input_mac"
    fi
    
    # Ports/mappings to forward (with validation)
    echo ""
    echo -e "${CYAN}These will be accessible on this server and forwarded to Server B${NC}"
    echo -e "${YELLOW}Forward protocol mode:${NC}"
    echo -e "  ${CYAN}1)${NC} TCP only (VLESS/V2Ray TCP)"
    echo -e "  ${CYAN}2)${NC} UDP only (WireGuard/Hysteria)"
    echo -e "  ${CYAN}3)${NC} Both TCP and UDP"
    read -p "Select [1]: " FORWARD_MODE_CHOICE < /dev/tty
    FORWARD_MODE_CHOICE=${FORWARD_MODE_CHOICE:-1}

    local FORWARD_MAPPINGS=""
    local FORWARD_TCP_MAPPINGS=""
    local FORWARD_UDP_MAPPINGS=""

    case "$FORWARD_MODE_CHOICE" in
        1)
            echo -e "${CYAN}Use same TCP port:${NC} ${YELLOW}443${NC}   ${CYAN}or map different TCP port:${NC} ${YELLOW}8443:443${NC}"
            read_forward_mappings "Enter TCP forward ports/mappings (comma-separated)" FORWARD_TCP_MAPPINGS "$DEFAULT_FORWARD_PORTS" "tcp"
            FORWARD_MAPPINGS="$FORWARD_TCP_MAPPINGS"
            ;;
        2)
            echo -e "${CYAN}Use same UDP port:${NC} ${YELLOW}51820${NC}   ${CYAN}or map different UDP port:${NC} ${YELLOW}1090:443/udp${NC}"
            read_forward_mappings "Enter UDP forward ports/mappings (comma-separated)" FORWARD_UDP_MAPPINGS "" "udp"
            FORWARD_MAPPINGS="$FORWARD_UDP_MAPPINGS"
            ;;
        3)
            echo -e "${CYAN}TCP mappings (examples):${NC} ${YELLOW}443${NC}, ${YELLOW}8443:443${NC}"
            read_forward_mappings "Enter TCP forward ports/mappings (comma-separated)" FORWARD_TCP_MAPPINGS "$DEFAULT_FORWARD_PORTS" "tcp"
            echo ""
            echo -e "${CYAN}UDP mappings (examples):${NC} ${YELLOW}51820/udp${NC}, ${YELLOW}1090:443/udp${NC}"
            read_forward_mappings "Enter UDP forward ports/mappings (comma-separated)" FORWARD_UDP_MAPPINGS "" "udp"
            if [ -n "$FORWARD_TCP_MAPPINGS" ] && [ -n "$FORWARD_UDP_MAPPINGS" ]; then
                FORWARD_MAPPINGS="${FORWARD_TCP_MAPPINGS},${FORWARD_UDP_MAPPINGS}"
            elif [ -n "$FORWARD_TCP_MAPPINGS" ]; then
                FORWARD_MAPPINGS="$FORWARD_TCP_MAPPINGS"
            elif [ -n "$FORWARD_UDP_MAPPINGS" ]; then
                FORWARD_MAPPINGS="$FORWARD_UDP_MAPPINGS"
            else
                print_error "No valid TCP/UDP forward mappings were provided."
                return 1
            fi
            ;;
        *)
            print_error "Invalid selection"
            return 1
            ;;
    esac
    
    # Check port conflicts
    echo ""
    IFS=',' read -ra MAPPING_SPECS <<< "$FORWARD_MAPPINGS"
    for spec in "${MAPPING_SPECS[@]}"; do
        spec=$(echo "$spec" | tr -d ' ')
        local listen_port
        local listen_proto
        listen_port=$(mapping_listen_port "$spec")
        listen_proto=$(mapping_protocol "$spec")
        check_port_conflict_proto "$listen_port" "$listen_proto" || return 0
    done

    # PaqX-style automatic profile (CPU/RAM-aware)
    echo ""
    calculate_auto_kcp_profile
    show_auto_kcp_profile
    
    # Download paqet (only if binary doesn't exist yet)
    if [ ! -f "$PAQET_BIN" ]; then
        download_paqet || return 0
    else
        print_success "paqet binary already installed"
    fi
    
    # Create forward configuration
    print_step "Creating configuration..."
    
    # Build forward section
    local forward_config=""
    if ! build_forward_config_from_mappings_csv "$FORWARD_MAPPINGS" forward_config; then
        print_error "Failed to build forward configuration from mappings: $FORWARD_MAPPINGS"
        return 1
    fi

    local profile_network_pcap_fragment=""
    local profile_transport_buf_fragment=""
    local profile_kcp_extra_fragment=""
    local profile_conn_value=""
    local profile_kcp_block=""
    local profile_kcp_mtu=""
    build_profile_network_pcap_fragment "client" profile_network_pcap_fragment
    build_profile_transport_buffer_fragment profile_transport_buf_fragment
    build_profile_kcp_extra_fragment profile_kcp_extra_fragment
    profile_conn_value=$(get_effective_profile_conn_value)
    profile_kcp_block=$(get_effective_profile_kcp_block)
    profile_kcp_mtu=$(get_effective_profile_kcp_mtu)
    
    cat > "$PAQET_CONFIG" << EOF
# paqet Client Configuration (Port Forwarding Mode)
# Tunnel: ${TUNNEL_NAME}
# Generated by installer on $(date)
role: "client"

log:
  level: "info"

# Port forwarding - accepts connections and forwards through tunnel
forward:${forward_config}

network:
  interface: "${interface}"
  ipv4:
    addr: "${local_ip}:0"
    router_mac: "${gateway_mac}"
  tcp:
    local_flag: ["PA"]
    remote_flag: ["PA"]
${profile_network_pcap_fragment}

server:
  addr: "${SERVER_B_IP}:${SERVER_B_PORT}"

transport:
  protocol: "kcp"${profile_transport_buf_fragment}
  conn: ${profile_conn_value}
  kcp:
    mode: "${DEFAULT_KCP_MODE}"
    key: "${SECRET_KEY}"
    mtu: ${profile_kcp_mtu}
    block: "${profile_kcp_block}"
${profile_kcp_extra_fragment}
EOF
    
    print_success "Configuration created: $PAQET_CONFIG"
    
    # Setup iptables protection rules for tunnel to Server B
    setup_iptables_client "$SERVER_B_IP" "$SERVER_B_PORT"
    apply_paqx_kernel_optimizations
    
    # Create systemd service
    create_systemd_service
    
    # Start service
    systemctl enable --now $PAQET_SERVICE
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}          Server A Tunnel '${TUNNEL_NAME}' Ready!              ${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${YELLOW}Tunnel Name:${NC}   ${CYAN}$TUNNEL_NAME${NC}"
    echo -e "  ${YELLOW}This Server:${NC}   ${CYAN}$public_ip${NC}"
    echo -e "  ${YELLOW}Server B:${NC}      ${CYAN}$SERVER_B_IP:$SERVER_B_PORT${NC}"
    echo -e "  ${YELLOW}Forwarding:${NC}    ${CYAN}$FORWARD_MAPPINGS${NC}"
    echo ""
    echo -e "${YELLOW}Client Connection:${NC}"
    echo -e "  Clients should connect to: ${CYAN}$advertised_host${NC}"
    local listen_ports_summary=""
    local listen_ports_summary_tcp=""
    local listen_ports_summary_udp=""
    for spec in "${MAPPING_SPECS[@]}"; do
        spec=$(echo "$spec" | tr -d ' ')
        local lp
        local proto
        lp=$(mapping_listen_port "$spec")
        proto=$(mapping_protocol "$spec")
        listen_ports_summary="${listen_ports_summary}${listen_ports_summary:+,}${lp}/${proto}"
        if [ "$proto" = "udp" ]; then
            listen_ports_summary_udp="${listen_ports_summary_udp}${listen_ports_summary_udp:+,}${lp}"
        else
            listen_ports_summary_tcp="${listen_ports_summary_tcp}${listen_ports_summary_tcp:+,}${lp}"
        fi
    done
    echo -e "  On ports: ${CYAN}$listen_ports_summary${NC}"
    [ -n "$listen_ports_summary_tcp" ] && echo -e "  TCP ports: ${CYAN}$listen_ports_summary_tcp${NC}"
    [ -n "$listen_ports_summary_udp" ] && echo -e "  UDP ports: ${CYAN}$listen_ports_summary_udp${NC}"
    if [ "$advertised_host" != "$public_ip" ]; then
        echo -e "  ${YELLOW}(Detected local IP was:${NC} ${CYAN}$public_ip${NC}${YELLOW})${NC}"
    fi
    echo ""
    echo -e "${YELLOW}Example endpoint updates:${NC}"
    for spec in "${MAPPING_SPECS[@]}"; do
        spec=$(echo "$spec" | tr -d ' ')
        local listen_port target_port proto
        listen_port=$(mapping_listen_port "$spec")
        target_port=$(mapping_target_port "$spec")
        proto=$(mapping_protocol "$spec")
        echo -e "  ${CYAN}[${proto}]${NC} ${RED}${SERVER_B_IP}:${target_port}${NC}  ->  ${GREEN}${advertised_host}:${listen_port}${NC}"
    done
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo -e "  Status:  ${CYAN}systemctl status $PAQET_SERVICE${NC}"
    echo -e "  Logs:    ${CYAN}journalctl -u $PAQET_SERVICE -f${NC}"
    echo -e "  Restart: ${CYAN}systemctl restart $PAQET_SERVICE${NC}"
    echo ""
    echo -e "${YELLOW}To add another tunnel, run setup again and choose a different name.${NC}"
    echo ""
}

#===============================================================================
# Status Check
#===============================================================================

check_status() {
    print_banner
    echo -e "${YELLOW}paqet Status${NC}"
    echo ""
    
    local configs=$(get_all_configs)
    
    if [ -z "$configs" ]; then
        print_error "No paqet configurations found"
        print_info "Run setup first"
        return 1
    fi
    
    # Show status of each tunnel
    while IFS= read -r config_file; do
        local name=$(get_tunnel_name "$config_file")
        local service=$(get_tunnel_service "$config_file")
        local role=$(grep "^role:" "$config_file" 2>/dev/null | awk '{print $2}' | tr -d '"')
        
        echo -e "${YELLOW}── Tunnel: ${CYAN}${name}${YELLOW} (${role}) ──${NC}"
        
        # Service status
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo -e "  Service: ${GREEN}● Running${NC}"
            local uptime=$(systemctl show "$service" --property=ActiveEnterTimestamp 2>/dev/null | cut -d'=' -f2)
            [ -n "$uptime" ] && echo -e "  Started: ${CYAN}$uptime${NC}"
        else
            echo -e "  Service: ${RED}● Stopped${NC}"
        fi
        
        # Details
        if [ "$role" = "server" ]; then
            local listen=$(grep -A1 "^listen:" "$config_file" 2>/dev/null | grep "addr:" | awk '{print $2}' | tr -d '"')
            echo -e "  Listen:  ${CYAN}$listen${NC}"
        else
            local server=$(grep -A1 "^server:" "$config_file" 2>/dev/null | grep "addr:" | awk '{print $2}' | tr -d '"')
            local forward_ports=$(grep 'listen:' "$config_file" 2>/dev/null | grep -oE ':[0-9]+"' | tr -d ':"' | tr '\n' ',' | sed 's/,$//')
            echo -e "  Server B: ${CYAN}$server${NC}"
            echo -e "  Ports:   ${CYAN}$forward_ports${NC}"
        fi
        
        # Recent logs (last 3 lines)
        local recent=$(journalctl -u "$service" -n 3 --no-pager 2>/dev/null | tail -3)
        if [ -n "$recent" ]; then
            echo -e "  ${YELLOW}Recent logs:${NC}"
            echo "$recent" | while IFS= read -r line; do
                echo "    $line"
            done
        fi
        
        echo ""
    done <<< "$configs"
    
    # Listening ports
    echo -e "${YELLOW}Listening Ports:${NC}"
    ss -tuln 2>/dev/null | grep -E "LISTEN" | awk '{print "  "$5}' | head -10 || echo "  None"
    
    echo ""
}

#===============================================================================
# Uninstall
#===============================================================================

uninstall() {
    print_banner
    echo -e "${YELLOW}Uninstalling paqet...${NC}"
    echo ""
    
    local configs=$(get_all_configs)
    
    if [ -n "$configs" ]; then
        echo -e "${YELLOW}Active tunnels:${NC}"
        echo ""
        list_tunnels
        echo ""
    fi
    
    # Stop and disable ALL tunnel services
    print_step "Stopping all paqet services..."
    
    if [ -n "$configs" ]; then
        while IFS= read -r config_file; do
            local service=$(get_tunnel_service "$config_file")
            local name=$(get_tunnel_name "$config_file")
            systemctl stop "$service" 2>/dev/null || true
            systemctl disable "$service" 2>/dev/null || true
            rm -f "/etc/systemd/system/${service}.service"
            print_success "  Stopped: $name ($service)"
        done <<< "$configs"
    fi
    
    # Also try legacy service in case it wasn't in configs
    systemctl stop paqet 2>/dev/null || true
    systemctl disable paqet 2>/dev/null || true
    rm -f /etc/systemd/system/paqet.service
    
    # Remove auto-reset timer
    systemctl stop ${AUTO_RESET_TIMER}.timer 2>/dev/null || true
    systemctl disable ${AUTO_RESET_TIMER}.timer 2>/dev/null || true
    rm -f /etc/systemd/system/${AUTO_RESET_TIMER}.timer
    rm -f /etc/systemd/system/${AUTO_RESET_SERVICE}.service
    
    systemctl daemon-reload
    print_success "All services removed"
    
    # Remove iptables rules
    print_step "Removing iptables rules..."
    
    # Remove Server B rules (try common ports)
    for port in 8888 9999 8080; do
        iptables -t raw -D PREROUTING -p tcp --dport $port -j NOTRACK 2>/dev/null || true
        iptables -t raw -D OUTPUT -p tcp --sport $port -j NOTRACK 2>/dev/null || true
        iptables -t mangle -D OUTPUT -p tcp --sport $port --tcp-flags RST RST -j DROP 2>/dev/null || true
        iptables -t mangle -D PREROUTING -p tcp --dport $port --tcp-flags RST RST -j DROP 2>/dev/null || true
    done
    
    # Remove Server A (client) rules by reading existing configs
    if [ -n "$configs" ]; then
        while IFS= read -r config_file; do
            local role=$(grep "^role:" "$config_file" 2>/dev/null | awk '{print $2}' | tr -d '"')
            if [ "$role" = "client" ]; then
                local server_addr=$(grep -A1 "^server:" "$config_file" 2>/dev/null | grep "addr:" | awk '{print $2}' | tr -d '"')
                local s_ip=$(echo "$server_addr" | cut -d':' -f1)
                local s_port=$(echo "$server_addr" | cut -d':' -f2)
                if [ -n "$s_ip" ] && [ -n "$s_port" ]; then
                    remove_iptables_client "$s_ip" "$s_port"
                fi
            fi
        done <<< "$configs"
    fi
    
    save_iptables
    print_success "iptables rules removed"
    
    # Ask about config preservation
    echo ""
    read_confirm "Remove all configurations and binary?" remove_all "n"
    
    if [ "$remove_all" = true ]; then
        rm -rf "$PAQET_DIR"
        print_success "All paqet files removed"
    else
        print_warning "Configurations preserved at: $PAQET_DIR/"
    fi

    if [ -f "$OPTIMIZE_SYSCTL_FILE" ]; then
        rm -f "$OPTIMIZE_SYSCTL_FILE"
        sysctl --system >/dev/null 2>&1 || true
        print_success "Removed kernel optimization file: $OPTIMIZE_SYSCTL_FILE"
    fi
    
    # Ask about removing the command
    if is_command_installed; then
        echo ""
        read_confirm "Also remove 'paqet-tunnel' command?" remove_cmd "n"
        if [ "$remove_cmd" = true ]; then
            uninstall_command
        fi
    fi
    
    echo ""
    print_success "paqet uninstalled"
    echo ""
}

#===============================================================================
# View/Edit Configuration
#===============================================================================

view_config() {
    print_banner
    echo -e "${YELLOW}View Configuration${NC}"
    echo ""
    
    # Select tunnel if multiple exist
    select_tunnel "Select tunnel to view" || return 1
    
    echo ""
    local name=$(get_tunnel_name "$PAQET_CONFIG")
    echo -e "${YELLOW}Configuration for tunnel '${name}':${NC}"
    echo ""
    
    if [ -f "$PAQET_CONFIG" ]; then
        cat "$PAQET_CONFIG"
    else
        print_error "Configuration not found at $PAQET_CONFIG"
    fi
    
    echo ""
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read < /dev/tty
}

#===============================================================================
# Edit Configuration
#===============================================================================

edit_config() {
    print_banner
    echo -e "${YELLOW}Edit Configuration${NC}"
    echo ""
    
    # Select tunnel if multiple exist
    select_tunnel "Select tunnel to edit" || return 1
    
    # Detect current role
    local role=$(grep "^role:" "$PAQET_CONFIG" 2>/dev/null | awk '{print $2}' | tr -d '"')
    local name=$(get_tunnel_name "$PAQET_CONFIG")
    
    echo ""
    echo -e "Tunnel: ${CYAN}$name${NC}  Role: ${CYAN}$role${NC}"
    echo ""
    echo -e "${YELLOW}What would you like to edit?${NC}"
    echo ""
    echo -e "  ${CYAN}1)${NC} Port Settings (V2Ray/paqet ports)"
    echo -e "  ${CYAN}2)${NC} Change secret key"
    echo -e "  ${CYAN}3)${NC} Change KCP settings"
    echo -e "  ${CYAN}4)${NC} Change network interface"
    if [ "$role" = "client" ]; then
        echo -e "  ${CYAN}5)${NC} Change Server B address"
    fi
    echo -e "  ${CYAN}6)${NC} Manual edit config file (advanced)"
    echo -e "  ${CYAN}0)${NC} Back to main menu"
    echo ""
    
    read -p "Choice: " edit_choice < /dev/tty
    
    case $edit_choice in
        1) port_settings_menu ;;
        2) edit_secret_key ;;
        3) edit_kcp_settings ;;
        4) edit_interface ;;
        5) 
            if [ "$role" = "client" ]; then
                edit_server_address
            else
                print_error "Invalid choice"
            fi
            ;;
        6)
            manual_edit_config_file
            ;;
        0) return 0 ;;
        *) print_error "Invalid choice" ;;
    esac
}

get_preferred_text_editor() {
    if [ -n "$EDITOR" ]; then
        echo "$EDITOR"
        return 0
    fi
    if command -v nano >/dev/null 2>&1; then
        echo "nano"
        return 0
    fi
    if command -v vim >/dev/null 2>&1; then
        echo "vim"
        return 0
    fi
    if command -v vi >/dev/null 2>&1; then
        echo "vi"
        return 0
    fi
    return 1
}

manual_edit_config_file() {
    echo ""
    echo -e "${YELLOW}Manual Config Edit (Advanced)${NC}"
    echo -e "${CYAN}File:${NC} $PAQET_CONFIG"
    echo ""
    print_warning "You are about to edit the raw YAML config manually."
    print_warning "Invalid YAML or wrong values can prevent the service from starting."
    echo ""

    if [ ! -f "$PAQET_CONFIG" ]; then
        print_error "Configuration file not found: $PAQET_CONFIG"
        return 1
    fi

    local editor_cmd=""
    if ! editor_cmd=$(get_preferred_text_editor); then
        print_error "No editor found (set \$EDITOR or install nano/vim/vi)."
        return 1
    fi

    local backup_file="${PAQET_CONFIG}.manualedit.bak.$(date +%s)"
    if cp "$PAQET_CONFIG" "$backup_file" 2>/dev/null; then
        print_info "Backup created: $backup_file"
    else
        print_warning "Could not create backup file before editing"
    fi

    echo -e "${CYAN}Opening with:${NC} $editor_cmd"
    echo ""

    # Support EDITOR values with arguments (e.g. "vim -u NONE")
    if ! sh -c "$editor_cmd \"$PAQET_CONFIG\"" < /dev/tty > /dev/tty 2>&1; then
        print_warning "Editor exited with a non-zero status"
    fi

    echo ""
    read_confirm "Restart paqet service to apply manual changes?" restart_now "y"
    if [ "$restart_now" = true ]; then
        if systemctl restart "$PAQET_SERVICE" >/dev/null 2>&1; then
            print_success "Service restarted"
        else
            print_error "Service failed to restart"
            print_info "Check logs: journalctl -u $PAQET_SERVICE -n 50"
        fi
    fi
}

edit_ports() {
    local role=$1
    echo ""
    
    if [ "$role" = "server" ]; then
        local current_port=$(grep -A1 "^listen:" "$PAQET_CONFIG" | grep "addr:" | sed 's/.*:\([0-9]*\)".*/\1/')
        read_port "Enter new paqet listen port" NEW_PORT "$current_port"
        
        # Update config file
        sed -i "s/addr: \":[0-9]*\"/addr: \":${NEW_PORT}\"/" "$PAQET_CONFIG"
        
        # Update iptables
        setup_iptables "$NEW_PORT"
        
        print_success "Port updated to $NEW_PORT"
    else
        echo -e "${CYAN}Current forward configuration:${NC}"
        get_current_forward_mappings | while read spec; do
            [ -n "$spec" ] && echo "  - $spec"
        done
        echo ""
        
        local current_mappings=$(get_current_forward_mappings | paste -sd, -)
        [ -z "$current_mappings" ] && current_mappings="$DEFAULT_FORWARD_PORTS"
        read_forward_mappings "Enter new forward ports/mappings (comma-separated)" NEW_MAPPINGS "$current_mappings"
        
        # Rebuild forward section
        local forward_config=""
        if ! build_forward_config_from_mappings_csv "$NEW_MAPPINGS" forward_config; then
            print_error "Failed to build forward configuration"
            return 1
        fi
        
        # Use awk to replace the forward section
        awk -v new_forward="forward:${forward_config}" '
            /^forward:/ { in_forward=1; print new_forward; next }
            in_forward && /^[a-z]/ { in_forward=0 }
            !in_forward { print }
        ' "$PAQET_CONFIG" > "${PAQET_CONFIG}.tmp"
        mv "${PAQET_CONFIG}.tmp" "$PAQET_CONFIG"
        
        print_success "Forward mappings updated"
    fi
    
    echo ""
    read_confirm "Restart paqet service to apply changes?" restart_now "y"
    if [ "$restart_now" = true ]; then
        systemctl restart $PAQET_SERVICE
        print_success "Service restarted"
    fi
}

#===============================================================================
# V2Ray/Forward Port Settings Menu
#===============================================================================

port_settings_menu() {
    local role=$(grep "^role:" "$PAQET_CONFIG" 2>/dev/null | awk '{print $2}' | tr -d '"')
    
    while true; do
        print_banner
        echo -e "${YELLOW}Port Settings${NC}"
        echo ""
        
        # Show current configuration
        echo -e "${YELLOW}Current Configuration:${NC}"
        echo -e "  Role: ${CYAN}$role${NC}"
        
        if [ "$role" = "server" ]; then
            local paqet_port=$(grep -A1 "^listen:" "$PAQET_CONFIG" | grep "addr:" | sed 's/.*:\([0-9]*\)".*/\1/')
            echo -e "  paqet tunnel port: ${CYAN}$paqet_port${NC}"
            echo ""
            echo -e "${YELLOW}Note:${NC} Server B doesn't configure V2Ray ports directly."
            echo -e "       V2Ray runs separately on its own ports."
        else
            local server_addr=$(grep -A1 "^server:" "$PAQET_CONFIG" | grep "addr:" | awk '{print $2}' | tr -d '"')
            local server_port=$(echo "$server_addr" | cut -d':' -f2)
            echo -e "  Server B paqet port: ${CYAN}$server_port${NC}"
            echo ""
            echo -e "  ${YELLOW}Forward Mappings (Iran -> Server B local, TCP/UDP):${NC}"
            get_current_forward_mappings | while read spec; do
                [ -z "$spec" ] && continue
                echo -e "    - ${CYAN}$spec${NC}"
            done
        fi
        
        echo ""
        echo -e "${YELLOW}Options:${NC}"
        echo ""
        
        if [ "$role" = "server" ]; then
            echo -e "  ${CYAN}1)${NC} Change paqet tunnel port"
        else
            echo -e "  ${CYAN}1)${NC} Change paqet tunnel port (Server B connection)"
            echo -e "  ${CYAN}2)${NC} Add forward mapping(s) (TCP/UDP)"
            echo -e "  ${CYAN}3)${NC} Remove forward mapping (TCP/UDP)"
            echo -e "  ${CYAN}4)${NC} Replace all forward mappings (TCP/UDP)"
        fi
        echo -e "  ${CYAN}0)${NC} Back to main menu"
        echo ""
        
        read -p "Choice: " port_choice < /dev/tty
        
        case $port_choice in
            1) 
                if [ "$role" = "server" ]; then
                    change_paqet_port_server
                else
                    change_paqet_port_client
                fi
                ;;
            2) 
                if [ "$role" = "client" ]; then
                    add_forward_ports
                else
                    print_error "Invalid choice"
                fi
                ;;
            3) 
                if [ "$role" = "client" ]; then
                    remove_forward_port
                else
                    print_error "Invalid choice"
                fi
                ;;
            4) 
                if [ "$role" = "client" ]; then
                    replace_all_forward_ports
                else
                    print_error "Invalid choice"
                fi
                ;;
            0) return 0 ;;
            *) print_error "Invalid choice" ;;
        esac
        
        echo ""
        echo -e "${YELLOW}Press Enter to continue...${NC}"
        read < /dev/tty
    done
}

# Get current forward ports from config
get_current_forward_ports() {
    # Extract port from listen: "0.0.0.0:PORT" format
    grep 'listen:' "$PAQET_CONFIG" 2>/dev/null | grep -oE ':[0-9]+"' | tr -d ':"' | sort -nu
}

# Get current forward mappings from config
# Outputs one item per line:
#   443
#   8443:443
#   51820/udp
#   1090:443/udp
get_current_forward_mappings() {
    awk '
        /^forward:/ { in_forward=1; next }
        in_forward && /^[a-z]/ { in_forward=0 }
        in_forward && /listen:/ {
            line=$0
            sub(/^.*:/, "", line)
            sub(/".*$/, "", line)
            listen=line
        }
        in_forward && /target:/ {
            line=$0
            sub(/^.*:/, "", line)
            sub(/".*$/, "", line)
            target=line
        }
        in_forward && /protocol:/ {
            line=$0
            sub(/^.*protocol:[[:space:]]*/, "", line)
            gsub(/"/, "", line)
            sub(/[[:space:]]*#.*$/, "", line)
            gsub(/[[:space:]]/, "", line)
            proto=line
            if (proto == "") proto="tcp"
            if (listen != "") {
                if (target == "" || target == listen) spec=listen
                else spec=listen ":" target
                if (proto == "udp") spec=spec "/udp"
                print spec
                listen=""
                target=""
                proto=""
            }
        }
    ' "$PAQET_CONFIG" 2>/dev/null
}

has_udp_forward_entries() {
    get_current_forward_mappings 2>/dev/null | grep -q '/udp$'
}

# Change paqet port on Server B
change_paqet_port_server() {
    echo ""
    local current_port=$(grep -A1 "^listen:" "$PAQET_CONFIG" | grep "addr:" | sed 's/.*:\([0-9]*\)".*/\1/')
    local current_ip_port=$(grep -A2 "^network:" "$PAQET_CONFIG" | grep -A1 "ipv4:" | grep "addr:" | awk '{print $2}' | tr -d '"')
    local current_ip=$(echo "$current_ip_port" | cut -d':' -f1)
    
    echo -e "Current paqet port: ${CYAN}$current_port${NC}"
    echo ""
    
    read_port "Enter new paqet listen port" NEW_PORT "$current_port"
    
    if [ "$NEW_PORT" = "$current_port" ]; then
        print_info "Port unchanged"
        return 0
    fi
    
    # Check port conflict
    check_port_conflict "$NEW_PORT" || return 0
    
    # Update listen section
    sed -i "s/addr: \":[0-9]*\"/addr: \":${NEW_PORT}\"/" "$PAQET_CONFIG"
    
    # Update network.ipv4.addr section
    sed -i "s|addr: \"${current_ip}:[0-9]*\"|addr: \"${current_ip}:${NEW_PORT}\"|" "$PAQET_CONFIG"
    
    # Update iptables
    setup_iptables "$NEW_PORT"
    
    print_success "paqet port updated to $NEW_PORT"
    
    echo ""
    read_confirm "Restart paqet service to apply changes?" restart_now "y"
    if [ "$restart_now" = true ]; then
        systemctl restart $PAQET_SERVICE
        print_success "Service restarted"
    fi
    
    echo ""
    print_warning "Remember to update Server A with the new port!"
}

# Change paqet port on Server A (connection to Server B)
change_paqet_port_client() {
    echo ""
    local server_addr=$(grep -A1 "^server:" "$PAQET_CONFIG" | grep "addr:" | awk '{print $2}' | tr -d '"')
    local server_ip=$(echo "$server_addr" | cut -d':' -f1)
    local server_port=$(echo "$server_addr" | cut -d':' -f2)
    
    echo -e "Current Server B address: ${CYAN}$server_addr${NC}"
    echo ""
    
    read_port "Enter Server B paqet port" NEW_PORT "$server_port"
    
    if [ "$NEW_PORT" = "$server_port" ]; then
        print_info "Port unchanged"
        return 0
    fi
    
    # Update server address
    sed -i "s|addr: \"${server_ip}:${server_port}\"|addr: \"${server_ip}:${NEW_PORT}\"|" "$PAQET_CONFIG"
    
    # Update iptables rules for new port
    remove_iptables_client "$server_ip" "$server_port"
    setup_iptables_client "$server_ip" "$NEW_PORT"
    
    print_success "Server B port updated to $NEW_PORT"
    
    echo ""
    read_confirm "Restart paqet service to apply changes?" restart_now "y"
    if [ "$restart_now" = true ]; then
        systemctl restart $PAQET_SERVICE
        print_success "Service restarted"
    fi
}

# Add new forward port(s)
add_forward_ports() {
    echo ""
    echo -e "${CYAN}Current forward mappings:${NC}"
    local current_mappings_csv=$(get_current_forward_mappings | paste -sd, -)
    [ -z "$current_mappings_csv" ] && current_mappings_csv=$(get_current_forward_ports | tr '\n' ',' | sed 's/,$//')
    echo -e "  ${YELLOW}$current_mappings_csv${NC}"
    echo ""
    
    read_forward_mappings "Enter port(s)/mapping(s) to ADD (comma-separated)" NEW_MAPPINGS "" "tcp"
    
    # Get existing listen/protocol keys and existing mappings
    local existing_keys=""
    local existing_mappings="$current_mappings_csv"
    local existing_spec=""
    while read existing_spec; do
        [ -z "$existing_spec" ] && continue
        existing_keys="${existing_keys} $(mapping_protocol "$existing_spec"):$(mapping_listen_port "$existing_spec")"
    done <<< "$(get_current_forward_mappings)"
    
    # Parse new mappings and check for duplicates/conflicts (by protocol+listen)
    local mappings_to_add=""
    local duplicates=""
    IFS=',' read -ra NEW_PORT_ARRAY <<< "$NEW_MAPPINGS"
    for spec in "${NEW_PORT_ARRAY[@]}"; do
        spec=$(echo "$spec" | tr -d ' ')
        [ -z "$spec" ] && continue
        local listen_port proto key
        listen_port=$(mapping_listen_port "$spec")
        proto=$(mapping_protocol "$spec")
        key="${proto}:${listen_port}"
        if echo " $existing_keys " | grep -qw "$key"; then
            duplicates="${duplicates}${listen_port}/${proto} "
        else
            # Check port conflict for the same protocol only
            if ! check_port_conflict_proto "$listen_port" "$proto"; then
                echo -e "${YELLOW}Add anyway? (y/n)${NC}"
                read -p "> " add_anyway < /dev/tty
                if [[ ! "$add_anyway" =~ ^[Yy]$ ]]; then
                    continue
                fi
            fi
            mappings_to_add="${mappings_to_add}${mappings_to_add:+,}${spec}"
            existing_keys="${existing_keys} ${key}"
        fi
    done
    
    if [ -n "$duplicates" ]; then
        print_warning "Skipping duplicate mappings: $duplicates"
    fi
    
    if [ -z "$mappings_to_add" ]; then
        print_info "No new ports/mappings to add"
        return 0
    fi
    
    # Combine existing and new mappings
    local all_mappings="$existing_mappings"
    [ -z "$all_mappings" ] && all_mappings="$mappings_to_add" || all_mappings="${all_mappings},${mappings_to_add}"
    
    # Rebuild forward section
    rebuild_forward_config "$all_mappings" || return 1
    
    print_success "Added mappings: $mappings_to_add"
    
    echo ""
    read_confirm "Restart paqet service to apply changes?" restart_now "y"
    if [ "$restart_now" = true ]; then
        systemctl restart $PAQET_SERVICE
        print_success "Service restarted"
    fi
}

# Remove a forward port
remove_forward_port() {
    echo ""
    echo -e "${CYAN}Current forward mappings:${NC}"
    local current_mappings_list=$(get_current_forward_mappings)
    local port_count=0
    local mappings_array=()
    
    while read spec; do
        if [ -n "$spec" ]; then
            port_count=$((port_count + 1))
            mappings_array+=("$spec")
            echo -e "  ${CYAN}$port_count)${NC} $spec"
        fi
    done <<< "$current_mappings_list"
    
    if [ $port_count -eq 0 ]; then
        print_error "No forward ports configured"
        return 1
    fi
    
    if [ $port_count -eq 1 ]; then
        print_error "Cannot remove the last port. At least one forward port is required."
        return 1
    fi
    
    echo ""
    echo -e "${YELLOW}Enter the mapping number to remove, or exact mapping (e.g. 1090:443/udp, 443):${NC}"
    read -p "> " remove_input < /dev/tty
    
    local mapping_to_remove=""
    
    # Check if input is a menu number or exact mapping
    if [[ "$remove_input" =~ ^[0-9]+$ ]] && [ "$remove_input" -le "$port_count" ] && [ "$remove_input" -gt 0 ]; then
        mapping_to_remove="${mappings_array[$((remove_input - 1))]}"
    else
        local normalized_remove=""
        if ! normalize_forward_mappings_input "$remove_input" normalized_remove "tcp"; then
            print_error "Invalid mapping input"
            return 1
        fi
        if echo "$normalized_remove" | grep -q ','; then
            print_error "Please enter exactly one mapping to remove"
            return 1
        fi
        mapping_to_remove="$normalized_remove"
    fi
    
    # Verify exact mapping exists, or resolve shorthand if uniquely identifiable.
    if ! echo "$current_mappings_list" | grep -Fxq "$mapping_to_remove"; then
        local shorthand_mode=""
        local shorthand_listen=""
        local shorthand_proto=""

        if [[ "$remove_input" =~ ^[0-9]+$ ]]; then
            shorthand_mode="listen_only"
            shorthand_listen="$remove_input"
        elif [[ "$remove_input" =~ ^([0-9]+)/(tcp|udp)$ ]]; then
            shorthand_mode="listen_proto"
            shorthand_listen="${BASH_REMATCH[1]}"
            shorthand_proto="${BASH_REMATCH[2]}"
        fi

        if [ -n "$shorthand_mode" ]; then
            local matches=()
            local spec=""
            while read spec; do
                [ -z "$spec" ] && continue
                if [ "$shorthand_mode" = "listen_only" ]; then
                    [ "$(mapping_listen_port "$spec")" = "$shorthand_listen" ] && matches+=("$spec")
                else
                    [ "$(mapping_listen_port "$spec")" = "$shorthand_listen" ] && [ "$(mapping_protocol "$spec")" = "$shorthand_proto" ] && matches+=("$spec")
                fi
            done <<< "$current_mappings_list"

            if [ "${#matches[@]}" -eq 1 ]; then
                mapping_to_remove="${matches[0]}"
            elif [ "${#matches[@]}" -gt 1 ]; then
                print_error "Multiple mappings match '$remove_input'. Use exact mapping (e.g. ${matches[0]})."
                return 1
            else
                print_error "Mapping '$remove_input' is not in the current configuration"
                return 1
            fi
        else
            print_error "Mapping '$mapping_to_remove' is not in the current configuration"
            return 1
        fi
    fi
    
    # Build new mapping list without the removed exact mapping
    local new_mappings=""
    for spec in "${mappings_array[@]}"; do
        if [ "$spec" != "$mapping_to_remove" ]; then
            new_mappings="${new_mappings}${new_mappings:+,}${spec}"
        fi
    done
    
    # Rebuild forward section
    rebuild_forward_config "$new_mappings" || return 1
    
    print_success "Removed mapping: $mapping_to_remove"
    
    echo ""
    read_confirm "Restart paqet service to apply changes?" restart_now "y"
    if [ "$restart_now" = true ]; then
        systemctl restart $PAQET_SERVICE
        print_success "Service restarted"
    fi
}

# Replace all forward ports
replace_all_forward_ports() {
    echo ""
    echo -e "${CYAN}Current forward mappings:${NC}"
    local current_mappings=$(get_current_forward_mappings | paste -sd, -)
    [ -z "$current_mappings" ] && current_mappings=$(get_current_forward_ports | tr '\n' ',' | sed 's/,$//')
    echo -e "  ${YELLOW}$current_mappings${NC}"
    echo ""
    
    print_warning "This will replace ALL current forward ports!"
    echo ""
    
    read_forward_mappings "Enter new forward ports/mappings (comma-separated)" NEW_MAPPINGS "$current_mappings" "tcp"
    
    # Check port conflicts (protocol-aware); ignore currently configured same protocol+listen pairs
    local current_keys=""
    local cur_spec=""
    while read cur_spec; do
        [ -z "$cur_spec" ] && continue
        current_keys="${current_keys} $(mapping_protocol "$cur_spec"):$(mapping_listen_port "$cur_spec")"
    done <<< "$(get_current_forward_mappings)"
    IFS=',' read -ra PORTS <<< "$NEW_MAPPINGS"
    local mappings_str=""
    for spec in "${PORTS[@]}"; do
        spec=$(echo "$spec" | tr -d ' ')
        [ -z "$spec" ] && continue
        local listen_port proto key
        listen_port=$(mapping_listen_port "$spec")
        proto=$(mapping_protocol "$spec")
        key="${proto}:${listen_port}"
        if ! echo " $current_keys " | grep -qw "$key"; then
            if ! check_port_conflict_proto "$listen_port" "$proto"; then
                echo -e "${YELLOW}Include anyway? (y/n)${NC}"
                read -p "> " include_anyway < /dev/tty
                if [[ ! "$include_anyway" =~ ^[Yy]$ ]]; then
                    continue
                fi
            fi
        fi
        mappings_str="${mappings_str}${mappings_str:+,}${spec}"
    done
    
    if [ -z "$mappings_str" ]; then
        print_error "No valid ports/mappings provided"
        return 1
    fi
    
    # Rebuild forward section
    rebuild_forward_config "$mappings_str" || return 1
    
    print_success "Forward mappings updated to: $mappings_str"
    
    echo ""
    read_confirm "Restart paqet service to apply changes?" restart_now "y"
    if [ "$restart_now" = true ]; then
        systemctl restart $PAQET_SERVICE
        print_success "Service restarted"
    fi
}

# Helper: Rebuild the forward config section
rebuild_forward_config() {
    local mappings_input="$1"
    local mappings_csv=""
    if ! normalize_forward_mappings_input "$mappings_input" mappings_csv; then
        return 1
    fi
    
    local forward_config=""
    if ! build_forward_config_from_mappings_csv "$mappings_csv" forward_config; then
        print_error "Failed to build forward configuration"
        return 1
    fi
    
    # Use awk to replace the forward section
    awk -v new_forward="forward:${forward_config}" '
        /^forward:/ { in_forward=1; print new_forward; next }
        in_forward && /^[a-z]/ { in_forward=0 }
        !in_forward { print }
    ' "$PAQET_CONFIG" > "${PAQET_CONFIG}.tmp"
    mv "${PAQET_CONFIG}.tmp" "$PAQET_CONFIG"
    return 0
}

edit_secret_key() {
    echo ""
    local new_key=$(generate_secret_key)
    echo -e "${CYAN}Generated new key: $new_key${NC}"
    read_required "Enter new secret key (or use generated)" SECRET_KEY "$new_key"
    
    sed -i "s/key: \"[^\"]*\"/key: \"${SECRET_KEY}\"/" "$PAQET_CONFIG"
    print_success "Secret key updated"
    
    print_warning "Remember to update the key on the other server as well!"
    
    echo ""
    read_confirm "Restart paqet service to apply changes?" restart_now "y"
    if [ "$restart_now" = true ]; then
        systemctl restart $PAQET_SERVICE
        print_success "Service restarted"
    fi
}

edit_kcp_settings() {
    echo ""
    load_active_profile_preset_defaults
    echo -e "${YELLOW}KCP Mode options:${NC}"
    echo -e "  ${CYAN}normal${NC}  - Balanced (default)"
    echo -e "  ${CYAN}fast${NC}    - Low latency"
    echo -e "  ${CYAN}fast2${NC}   - Lower latency"
    echo -e "  ${CYAN}fast3${NC}   - Aggressive, best for high latency"
    echo ""
    
    local current_mode=$(grep "mode:" "$PAQET_CONFIG" | awk '{print $2}' | tr -d '"')
    read_required "Enter KCP mode" KCP_MODE "$current_mode"
    
    local current_conn=$(grep "conn:" "$PAQET_CONFIG" | awk '{print $2}')
    read_required "Enter number of parallel connections (1-8)" KCP_CONN "$current_conn"
    
    echo ""
    echo -e "${YELLOW}MTU (Maximum Transmission Unit):${NC}"
    echo -e "  ${CYAN}1400-1500${NC} - Normal networks"
    echo -e "  ${CYAN}${PROFILE_PRESET_KCP_MTU}${NC}      - Active profile baseline (${PROFILE_PRESET_NAME})"
    echo -e "  ${CYAN}1280-1300${NC} - Restrictive networks / EOF or connection issues"
    echo -e "  ${YELLOW}Tip:${NC} If you get EOF errors, try MTU 1280 on BOTH ends of this tunnel."
    echo ""
    
    local current_mtu=$(grep "mtu:" "$PAQET_CONFIG" | grep -oE '[0-9]+' | head -1)
    [ -z "$current_mtu" ] && current_mtu="$PROFILE_PRESET_KCP_MTU"
    
    while true; do
        read_required "Enter MTU value, between 1280 and 1500" KCP_MTU "$current_mtu"
        if ! [[ "$KCP_MTU" =~ ^[0-9]+$ ]]; then
            print_error "MTU must be a number (e.g., 1350)"
            echo ""
            continue
        fi
        if [ "$KCP_MTU" -lt 1280 ] || [ "$KCP_MTU" -gt 1500 ]; then
            print_error "MTU must be between 1280 and 1500"
            echo ""
            continue
        fi
        break
    done
    
    sed -i "s/mode: \"[^\"]*\"/mode: \"${KCP_MODE}\"/" "$PAQET_CONFIG"
    sed -i "s/conn: [0-9]*/conn: ${KCP_CONN}/" "$PAQET_CONFIG"
    
    # Update or add MTU setting (match entire value after "mtu: " to handle corrupted values)
    if grep -q "mtu:" "$PAQET_CONFIG"; then
        sed -i "s/mtu: .*/mtu: ${KCP_MTU}/" "$PAQET_CONFIG"
    else
        # Add mtu after key line
        sed -i "/key:/a\\    mtu: ${KCP_MTU}" "$PAQET_CONFIG"
    fi
    
    print_success "KCP settings updated (mode: $KCP_MODE, conn: $KCP_CONN, mtu: $KCP_MTU)"
    
    echo ""
    read_confirm "Restart paqet service to apply changes?" restart_now "y"
    if [ "$restart_now" = true ]; then
        systemctl restart $PAQET_SERVICE
        print_success "Service restarted"
    fi
}

edit_interface() {
    echo ""
    local current_iface=$(grep "interface:" "$PAQET_CONFIG" | awk '{print $2}' | tr -d '"')
    echo -e "Current interface: ${CYAN}$current_iface${NC}"
    echo ""
    echo -e "${YELLOW}Available interfaces:${NC}"
    ip -o link show | awk -F': ' '{print "  " $2}'
    echo ""
    
    read_required "Enter network interface" NEW_IFACE "$current_iface"
    
    local new_ip=$(get_local_ip "$NEW_IFACE")
    if [ -z "$new_ip" ]; then
        read_ip "Could not detect IP. Enter local IP for $NEW_IFACE" new_ip
    fi
    
    local new_mac=$(get_gateway_mac)
    if [ -z "$new_mac" ]; then
        read_mac "Enter gateway MAC address" new_mac
    fi
    
    sed -i "s/interface: \"[^\"]*\"/interface: \"${NEW_IFACE}\"/" "$PAQET_CONFIG"
    sed -i "s/router_mac: \"[^\"]*\"/router_mac: \"${new_mac}\"/" "$PAQET_CONFIG"
    # Update IP in addr field (keeping the port)
    sed -i "s|addr: \"[0-9.]*:|addr: \"${new_ip}:|" "$PAQET_CONFIG"
    
    print_success "Network interface updated"
    
    echo ""
    read_confirm "Restart paqet service to apply changes?" restart_now "y"
    if [ "$restart_now" = true ]; then
        systemctl restart $PAQET_SERVICE
        print_success "Service restarted"
    fi
}

edit_server_address() {
    echo ""
    local current_addr=$(grep -A1 "^server:" "$PAQET_CONFIG" | grep "addr:" | awk '{print $2}' | tr -d '"')
    local current_ip=$(echo "$current_addr" | cut -d':' -f1)
    local current_port=$(echo "$current_addr" | cut -d':' -f2)
    
    echo -e "Current Server B: ${CYAN}$current_addr${NC}"
    echo ""
    
    read_ip "Enter Server B IP address" NEW_SERVER_IP "$current_ip"
    read_port "Enter Server B paqet port" NEW_SERVER_PORT "$current_port"
    
    sed -i "s|addr: \"${current_addr}\"|addr: \"${NEW_SERVER_IP}:${NEW_SERVER_PORT}\"|" "$PAQET_CONFIG"
    
    # Update iptables rules: remove old target, add new target
    if [ -n "$current_ip" ] && [ -n "$current_port" ]; then
        remove_iptables_client "$current_ip" "$current_port"
    fi
    setup_iptables_client "$NEW_SERVER_IP" "$NEW_SERVER_PORT"
    
    print_success "Server B address updated to ${NEW_SERVER_IP}:${NEW_SERVER_PORT}"
    
    echo ""
    read_confirm "Restart paqet service to apply changes?" restart_now "y"
    if [ "$restart_now" = true ]; then
        systemctl restart $PAQET_SERVICE
        print_success "Service restarted"
    fi
}

#===============================================================================
# Connection Test Tool
#===============================================================================

test_connection() {
    print_banner
    echo -e "${YELLOW}Connection Test Tool${NC}"
    echo ""
    
    # Select tunnel if multiple exist
    select_tunnel "Select tunnel to test" || return 1
    
    local role=$(grep "^role:" "$PAQET_CONFIG" 2>/dev/null | awk '{print $2}' | tr -d '"')
    local name=$(get_tunnel_name "$PAQET_CONFIG")
    
    echo ""
    echo -e "Tunnel: ${CYAN}$name${NC}  Role: ${CYAN}$role${NC}"
    echo ""
    
    # Check if service is running
    print_step "Checking paqet service..."
    if systemctl is-active --quiet $PAQET_SERVICE 2>/dev/null; then
        print_success "paqet service is running"
    else
        print_error "paqet service is NOT running"
        echo ""
        read_confirm "Would you like to start it?" start_svc "y"
        if [ "$start_svc" = true ]; then
            systemctl start $PAQET_SERVICE
            sleep 2
            if systemctl is-active --quiet $PAQET_SERVICE; then
                print_success "Service started"
            else
                print_error "Failed to start service"
                echo -e "${YELLOW}Check logs:${NC} journalctl -u $PAQET_SERVICE -n 20"
                return 1
            fi
        else
            return 1
        fi
    fi
    
    echo ""
    
    if [ "$role" = "server" ]; then
        # Server B tests
        test_server_b
    else
        # Server A tests
        test_server_a
    fi
}

test_server_b() {
    echo -e "${GREEN}Running Server B (Abroad) tests...${NC}"
    echo ""
    
    local listen_port=$(grep -A1 "^listen:" "$PAQET_CONFIG" | grep "addr:" | sed 's/.*:\([0-9]*\)".*/\1/')
    
    # Test 1: Check if paqet is listening
    print_step "Test 1: Checking if paqet is listening on port $listen_port..."
    if ss -tuln | grep -q ":${listen_port} "; then
        print_success "paqet is listening on port $listen_port"
    else
        print_warning "paqet might be using raw sockets (not visible in ss)"
        print_info "This is normal for paqet"
    fi
    
    echo ""
    
    # Test 2: Check iptables rules
    print_step "Test 2: Checking iptables rules..."
    local raw_rules=$(iptables -t raw -L -n 2>/dev/null | grep -c "$listen_port" || echo "0")
    local mangle_rules=$(iptables -t mangle -L -n 2>/dev/null | grep -c "$listen_port" || echo "0")
    
    if [ "$raw_rules" -gt 0 ] && [ "$mangle_rules" -gt 0 ]; then
        print_success "iptables rules are configured"
    else
        print_warning "Some iptables rules may be missing"
        print_info "Run setup again to reconfigure"
    fi
    
    echo ""
    
    # Test 3: Check for recent connections in logs
    print_step "Test 3: Checking recent activity..."
    local recent_logs=$(journalctl -u $PAQET_SERVICE --since "5 minutes ago" 2>/dev/null | tail -5)
    if [ -n "$recent_logs" ]; then
        echo "$recent_logs"
    else
        print_info "No recent activity in logs"
    fi
    
    echo ""
    
    # Test 4: External connectivity check
    print_step "Test 4: Checking external connectivity..."
    if curl -s --max-time 5 ifconfig.me >/dev/null 2>&1; then
        local public_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null)
        print_success "External connectivity OK (Public IP: $public_ip)"
    else
        print_warning "Cannot reach external services"
    fi
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Server B Checklist:${NC}"
    echo -e "  • Ensure port ${CYAN}$listen_port${NC} is open in cloud firewall"
    echo -e "  • Ensure V2Ray/X-UI listens on ${CYAN}0.0.0.0${NC}"
    echo -e "  • Share the secret key with Server A"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
}

test_server_a() {
    echo -e "${GREEN}Running Server A (Iran/Entry Point) tests...${NC}"
    echo ""
    
    local server_addr=$(grep -A1 "^server:" "$PAQET_CONFIG" | grep "addr:" | awk '{print $2}' | tr -d '"')
    local server_ip=$(echo "$server_addr" | cut -d':' -f1)
    local server_port=$(echo "$server_addr" | cut -d':' -f2)
    
    echo -e "Target Server B: ${CYAN}$server_addr${NC}"
    echo ""
    
    # Test 1: Basic network connectivity
    print_step "Test 1: Basic network connectivity to Server B..."
    if ping -c 1 -W 3 "$server_ip" >/dev/null 2>&1; then
        print_success "Server B is reachable via ICMP"
    else
        print_warning "ICMP blocked (this may be normal)"
    fi
    
    echo ""
    
    # Test 2: TCP connectivity to paqet port
    # NOTE: paqet uses raw sockets, so standard TCP probes won't get a response
    # This is EXPECTED - paqet is designed to be invisible to normal TCP
    print_step "Test 2: TCP probe to Server B port $server_port..."
    print_info "Note: paqet uses raw sockets - standard TCP may not respond"
    
    local tcp_reachable=false
    if timeout 5 bash -c "echo >/dev/tcp/$server_ip/$server_port" 2>/dev/null; then
        tcp_reachable=true
    elif command -v nc >/dev/null 2>&1; then
        if nc -z -w 5 "$server_ip" "$server_port" 2>/dev/null; then
            tcp_reachable=true
        fi
    fi
    
    if [ "$tcp_reachable" = true ]; then
        print_success "Port $server_port responds to TCP (unusual for paqet)"
    else
        print_warning "No TCP response on port $server_port"
        print_info "This is NORMAL - paqet operates at raw socket level"
        print_info "The tunnel may still work. Run end-to-end test to verify."
    fi
    
    echo ""
    
    # Test 3: Check connection protection iptables rules
    print_step "Test 3: Checking connection protection iptables rules..."
    local raw_rules=$(iptables -t raw -L -n 2>/dev/null | grep -c "$server_ip" || echo "0")
    local mangle_rules=$(iptables -t mangle -L -n 2>/dev/null | grep -c "$server_ip" || echo "0")
    
    if [ "$raw_rules" -gt 0 ] && [ "$mangle_rules" -gt 0 ]; then
        print_success "Connection protection iptables rules are active"
    else
        print_warning "Connection protection iptables rules are missing"
        print_info "Run 'Connection Protection & MTU Tuning' (option d) from the main menu to fix"
    fi
    
    echo ""
    
    # Test 4: Check forwarded ports
    print_step "Test 4: Checking forwarded ports..."
    local forward_ports=$(grep -A10 "^forward:" "$PAQET_CONFIG" | grep "listen:" | sed 's/.*:\([0-9]*\)".*/\1/' | tr '\n' ' ')
    
    for port in $forward_ports; do
        if ss -tuln | grep -q ":${port} "; then
            print_success "Port $port is listening"
        else
            print_warning "Port $port may be using raw sockets"
        fi
    done
    
    echo ""
    
    # Test 5: Check recent tunnel activity
    print_step "Test 5: Checking tunnel activity..."
    local recent_logs=$(journalctl -u $PAQET_SERVICE --since "5 minutes ago" 2>/dev/null | grep -iE "connect|tunnel|forward" | tail -3)
    if [ -n "$recent_logs" ]; then
        echo "$recent_logs"
    else
        print_info "No recent tunnel activity"
    fi
    
    echo ""
    
    # Test 6: End-to-end test (if user wants)
    echo -e "${YELLOW}Would you like to run an end-to-end test?${NC}"
    echo -e "${CYAN}This will attempt to connect through the tunnel.${NC}"
    read_confirm "Run end-to-end test?" run_e2e "n"
    
    if [ "$run_e2e" = true ]; then
        echo ""
        local test_port=$(echo "$forward_ports" | awk '{print $1}')
        print_step "Attempting connection through tunnel on port $test_port..."
        
        if timeout 10 bash -c "echo >/dev/tcp/127.0.0.1/$test_port" 2>/dev/null; then
            print_success "Tunnel connection successful!"
        else
            print_error "Tunnel connection failed"
            print_info "Check logs: journalctl -u $PAQET_SERVICE -f"
        fi
    fi
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Server A Checklist:${NC}"
    echo -e "  • Verify secret key matches Server B"
    echo -e "  • Ensure Server B's cloud firewall allows port $server_port"
    echo -e "  • TCP probe failing is NORMAL (paqet uses raw sockets)"
    echo -e "  • Update V2Ray clients to use this server's IP"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
}

#===============================================================================
# Manage Tunnels Menu
#===============================================================================

manage_tunnels_menu() {
    while true; do
        print_banner
        echo -e "${YELLOW}Manage Tunnels${NC}"
        echo ""
        
        # Show all tunnels
        local configs=$(get_all_configs)
        if [ -n "$configs" ]; then
            echo -e "${YELLOW}Current Tunnels:${NC}"
            echo ""
            list_tunnels
        else
            print_info "No tunnels configured yet"
        fi
        
        echo ""
        echo -e "${YELLOW}Options:${NC}"
        echo ""
        echo -e "  ${CYAN}1)${NC} Add new tunnel (setup Server A)"
        echo -e "  ${CYAN}2)${NC} Remove a tunnel"
        echo -e "  ${CYAN}3)${NC} Restart a tunnel"
        echo -e "  ${CYAN}4)${NC} Stop a tunnel"
        echo -e "  ${CYAN}5)${NC} Start a tunnel"
        echo -e "  ${CYAN}0)${NC} Back to main menu"
        echo ""
        
        read -p "Choice: " manage_choice < /dev/tty
        
        case $manage_choice in
            1) run_iran_optimizations; install_dependencies; setup_server_a ;;
            2) remove_tunnel ;;
            3) tunnel_service_action "restart" ;;
            4) tunnel_service_action "stop" ;;
            5) tunnel_service_action "start" ;;
            0) return 0 ;;
            *) print_error "Invalid choice" ;;
        esac
        
        echo ""
        echo -e "${YELLOW}Press Enter to continue...${NC}"
        read < /dev/tty
    done
}

# Remove a specific tunnel
remove_tunnel() {
    echo ""
    
    local configs=$(get_all_configs)
    if [ -z "$configs" ]; then
        print_error "No tunnels to remove"
        return 1
    fi
    
    select_tunnel "Select tunnel to remove" || return 1
    
    local name=$(get_tunnel_name "$PAQET_CONFIG")
    local service="$PAQET_SERVICE"
    
    echo ""
    print_warning "This will remove tunnel '$name':"
    echo -e "  Config:  ${CYAN}$PAQET_CONFIG${NC}"
    echo -e "  Service: ${CYAN}$service${NC}"
    echo ""
    
    read_confirm "Are you sure?" confirm_remove "n"
    
    if [ "$confirm_remove" = true ]; then
        # Remove iptables rules for this tunnel
        local role=$(grep "^role:" "$PAQET_CONFIG" 2>/dev/null | awk '{print $2}' | tr -d '"')
        if [ "$role" = "client" ]; then
            local server_addr=$(grep -A1 "^server:" "$PAQET_CONFIG" 2>/dev/null | grep "addr:" | awk '{print $2}' | tr -d '"')
            local s_ip=$(echo "$server_addr" | cut -d':' -f1)
            local s_port=$(echo "$server_addr" | cut -d':' -f2)
            if [ -n "$s_ip" ] && [ -n "$s_port" ]; then
                remove_iptables_client "$s_ip" "$s_port"
                save_iptables
            fi
        fi
        
        # Stop and disable service
        print_step "Stopping service $service..."
        systemctl stop "$service" 2>/dev/null || true
        systemctl disable "$service" 2>/dev/null || true
        rm -f "/etc/systemd/system/${service}.service"
        systemctl daemon-reload
        print_success "Service removed"
        
        # Remove config
        rm -f "$PAQET_CONFIG"
        print_success "Configuration removed"
        
        # Check if any tunnels remain
        local remaining=$(get_all_configs)
        if [ -z "$remaining" ]; then
            echo ""
            read_confirm "No tunnels remaining. Remove paqet binary too?" remove_bin "n"
            if [ "$remove_bin" = true ]; then
                rm -rf "$PAQET_DIR"
                print_success "All paqet files removed"
            fi
        fi
        
        echo ""
        print_success "Tunnel '$name' removed"
    else
        print_info "Cancelled"
    fi
    
    # Reset globals to defaults
    PAQET_CONFIG="$PAQET_DIR/config.yaml"
    PAQET_SERVICE="paqet"
}

# Restart/stop/start a tunnel service
tunnel_service_action() {
    local action="$1"
    echo ""
    
    select_tunnel "Select tunnel to $action" || return 1
    
    local name=$(get_tunnel_name "$PAQET_CONFIG")
    
    print_step "${action^}ing tunnel '$name' ($PAQET_SERVICE)..."
    
    if systemctl "$action" "$PAQET_SERVICE" 2>/dev/null; then
        sleep 1
        if [ "$action" = "stop" ]; then
            print_success "Tunnel '$name' stopped"
        elif systemctl is-active --quiet "$PAQET_SERVICE" 2>/dev/null; then
            print_success "Tunnel '$name' is running"
        else
            print_error "Tunnel '$name' failed to start"
            echo -e "${YELLOW}Check logs:${NC} journalctl -u $PAQET_SERVICE -n 20"
        fi
    else
        print_error "Failed to $action tunnel '$name'"
    fi
    
    # Reset globals
    PAQET_CONFIG="$PAQET_DIR/config.yaml"
    PAQET_SERVICE="paqet"
}

#===============================================================================
# Automatic Reset (periodic service restart for reliability)
#===============================================================================

# Read auto-reset config. Returns: ENABLED, INTERVAL, UNIT
read_auto_reset_config() {
    if [ -f "$AUTO_RESET_CONF" ]; then
        . "$AUTO_RESET_CONF"
    fi
    ENABLED="${ENABLED:-false}"
    INTERVAL="${INTERVAL:-6}"
    UNIT="${UNIT:-hour}"
}

# Write auto-reset config
write_auto_reset_config() {
    local enabled="$1"
    local interval="$2"
    local unit="$3"
    mkdir -p "$PAQET_DIR"
    cat > "$AUTO_RESET_CONF" << EOF
# Auto-reset config - restarts paqet services periodically for reliability
ENABLED="$enabled"
INTERVAL="$interval"
UNIT="$unit"
EOF
}

# Create the reset script that restarts all paqet services
create_auto_reset_script() {
    cat > "$AUTO_RESET_SCRIPT" << 'RESET_SCRIPT'
#!/bin/bash
# Auto-reset: restart all paqet services periodically for reliability

CONF="/opt/paqet/auto-reset.conf"
[ -f "$CONF" ] && . "$CONF"

[ "$ENABLED" != "true" ] && exit 0

for svc in /etc/systemd/system/paqet*.service; do
    [ -f "$svc" ] || continue
    name=$(basename "$svc" .service)
    [ "$name" = "paqet-auto-reset" ] && continue
    systemctl restart "$name" 2>/dev/null || true
done
RESET_SCRIPT
    chmod +x "$AUTO_RESET_SCRIPT"
}

# Create systemd service and timer for auto-reset
create_auto_reset_timer() {
    local interval="$1"
    local unit="$2"
    
    # Convert to systemd time format
    local period="${interval}${unit}"
    
    create_auto_reset_script
    
    cat > /etc/systemd/system/${AUTO_RESET_SERVICE}.service << EOF
[Unit]
Description=paqet Auto-Reset (periodic service restart for reliability)
After=network.target

[Service]
Type=oneshot
ExecStart=$AUTO_RESET_SCRIPT
EOF

    cat > /etc/systemd/system/${AUTO_RESET_TIMER}.timer << EOF
[Unit]
Description=paqet Auto-Reset Timer
Requires=${AUTO_RESET_SERVICE}.service

[Timer]
OnBootSec=10min
OnUnitActiveSec=${period}
Persistent=yes

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable --now ${AUTO_RESET_TIMER}.timer 2>/dev/null || true
    print_success "Auto-reset timer enabled (every $interval $unit(s))"
}

# Remove systemd timer and service
remove_auto_reset_timer() {
    systemctl stop ${AUTO_RESET_TIMER}.timer 2>/dev/null || true
    systemctl disable ${AUTO_RESET_TIMER}.timer 2>/dev/null || true
    rm -f "/etc/systemd/system/${AUTO_RESET_TIMER}.timer"
    rm -f "/etc/systemd/system/${AUTO_RESET_SERVICE}.service"
    systemctl daemon-reload
    print_success "Auto-reset timer disabled"
}

# Manual reset: restart all paqet services
manual_reset_all() {
    echo ""
    print_step "Restarting all paqet services..."
    
    local count=0
    local configs=$(get_all_configs)
    
    if [ -z "$configs" ]; then
        print_error "No tunnels configured"
        return 1
    fi
    
    while IFS= read -r config_file; do
        local service=$(get_tunnel_service "$config_file")
        local name=$(get_tunnel_name "$config_file")
        if systemctl restart "$service" 2>/dev/null; then
            print_success "Restarted: $name"
            count=$((count + 1))
        else
            print_warning "Could not restart: $name"
        fi
    done <<< "$configs"
    
    if [ $count -gt 0 ]; then
        print_success "Manual reset complete ($count service(s) restarted)"
    fi
    echo ""
}

#===============================================================================
# Connection Protection & MTU Tuning
#===============================================================================

apply_connection_protection() {
    print_banner
    echo -e "${YELLOW}Connection Protection & MTU Tuning${NC}"
    echo -e "${CYAN}Applies iptables rules to improve tunnel stability and resist fake disconnects${NC}"
    echo ""
    echo -e "${YELLOW}What this does:${NC}"
    echo -e "  - Blocks fake RST packets injected by ISP middleboxes"
    echo -e "  - Bypasses kernel connection tracking for tunnel traffic"
    echo -e "  - Prevents kernel from sending RST packets that break raw socket tunnels"
    echo -e "  - Optionally lowers MTU to avoid large-packet fingerprinting"
    echo ""
    
    local configs=$(get_all_configs)
    if [ -z "$configs" ]; then
        print_error "No tunnels configured. Set up a server first."
        return 1
    fi
    
    local applied=0
    
    while IFS= read -r config_file; do
        local name=$(get_tunnel_name "$config_file")
        local role=$(grep "^role:" "$config_file" 2>/dev/null | awk '{print $2}' | tr -d '"')
        
        if [ "$role" = "server" ]; then
            # Server B: apply server-side rules
            local listen_port=$(grep -A1 "^listen:" "$config_file" 2>/dev/null | grep "addr:" | grep -oE '[0-9]+' | tail -1)
            if [ -n "$listen_port" ]; then
                echo -e "${CYAN}Tunnel '${name}' (Server B) — port $listen_port${NC}"
                setup_iptables "$listen_port"
                applied=$((applied + 1))
            else
                print_warning "Could not detect port for tunnel '$name', skipping"
            fi
        elif [ "$role" = "client" ]; then
            # Server A: apply client-side rules targeting Server B
            local server_addr=$(grep -A1 "^server:" "$config_file" 2>/dev/null | grep "addr:" | awk '{print $2}' | tr -d '"')
            local s_ip=$(echo "$server_addr" | cut -d':' -f1)
            local s_port=$(echo "$server_addr" | cut -d':' -f2)
            if [ -n "$s_ip" ] && [ -n "$s_port" ]; then
                echo -e "${CYAN}Tunnel '${name}' (Server A) — target $s_ip:$s_port${NC}"
                setup_iptables_client "$s_ip" "$s_port"
                applied=$((applied + 1))
            else
                print_warning "Could not detect Server B address for tunnel '$name', skipping"
            fi
        fi
    done <<< "$configs"
    
    echo ""
    if [ "$applied" -gt 0 ]; then
        print_success "Protection rules applied to $applied tunnel(s)"
    else
        print_warning "No tunnels were updated"
    fi
    
    # Offer MTU reduction
    echo ""
    echo -e "${YELLOW}MTU Optimization:${NC}"
    echo -e "  Some ISP systems detect and block large packets."
    echo -e "  Lowering MTU can help avoid this fingerprinting."
    echo -e "  Current recommended value: ${CYAN}1280${NC}"
    echo ""
    
    read_confirm "Lower MTU to 1280 on all tunnels?" lower_mtu "y"
    
    if [ "$lower_mtu" = true ]; then
        local mtu_updated=0
        while IFS= read -r config_file; do
            local current_mtu=$(grep "mtu:" "$config_file" 2>/dev/null | grep -oE '[0-9]+' | head -1)
            if [ -n "$current_mtu" ] && [ "$current_mtu" -gt 1280 ]; then
                sed -i "s/mtu: .*/mtu: 1280/" "$config_file"
                local name=$(get_tunnel_name "$config_file")
                print_info "  $name: MTU $current_mtu -> 1280"
                mtu_updated=$((mtu_updated + 1))
            fi
        done <<< "$configs"
        
        if [ "$mtu_updated" -gt 0 ]; then
            print_success "MTU updated on $mtu_updated tunnel(s)"
            echo ""
            read_confirm "Restart all paqet services to apply changes?" restart_now "y"
            if [ "$restart_now" = true ]; then
                while IFS= read -r config_file; do
                    local service=$(get_tunnel_service "$config_file")
                    systemctl restart "$service" 2>/dev/null || true
                done <<< "$configs"
                print_success "All services restarted"
            fi
        else
            print_info "All tunnels already at MTU 1280 or below"
        fi
    fi
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}      Connection Protection & MTU Tuning Complete           ${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Active protections:${NC}"
    echo -e "  - Fake RST injection blocked (iptables mangle)"
    echo -e "  - Kernel connection tracking bypassed (iptables raw NOTRACK)"
    echo -e "  - Kernel RST responses suppressed"
    echo ""
    echo -e "${YELLOW}If issues persist:${NC}"
    echo -e "  - Try changing the paqet port to a less common port"
    echo -e "  - Try KCP mode 'fast3' for aggressive retransmission"
    echo -e "  - Apply this optimization on BOTH Server A and Server B"
    echo ""
}

#===============================================================================
# IPTables Port Forwarding Menu
#===============================================================================

iptables_port_forwarding_menu() {
    while true; do
        print_banner
        echo -e "${YELLOW}IPTables NAT Port Forwarding${NC}"
        echo -e "${CYAN}Forward traffic to another server using iptables NAT rules${NC}"
        echo -e "${CYAN}Each rule set is independent — useful for testing backup tunnels${NC}"
        echo ""
        
        # Quick status: show if IP forwarding is enabled
        local fwd_status=$(sysctl -n net.ipv4.ip_forward 2>/dev/null)
        if [ "$fwd_status" = "1" ]; then
            echo -e "  ${GREEN}[✓] IP forwarding is enabled${NC}"
        else
            echo -e "  ${YELLOW}[—] IP forwarding is disabled${NC}"
        fi
        
        local nat_count=$(iptables -t nat -L PREROUTING -n 2>/dev/null | grep -c "DNAT" || echo "0")
        echo -e "  ${CYAN}Active DNAT rules: ${nat_count}${NC}"
        echo ""
        
        echo -e "  ${CYAN}1)${NC} Multi-Port Forward (specific ports -> destination)"
        echo -e "  ${CYAN}2)${NC} All-Ports Forward (all except excluded -> destination)"
        echo -e "  ${CYAN}3)${NC} View NAT Rules"
        echo -e "  ${CYAN}4)${NC} Remove Forwarding by Destination IP"
        echo -e "  ${CYAN}5)${NC} Flush All NAT Rules"
        echo -e "  ${CYAN}0)${NC} Back"
        echo ""
        read -p "Choice: " fwd_choice < /dev/tty
        
        case $fwd_choice in
            1) add_nat_forward_multi_port ;;
            2) add_nat_forward_all_ports ;;
            3) view_nat_rules ;;
            4) remove_nat_forward_by_dest ;;
            5) flush_nat_rules ;;
            0) return ;;
            *) print_error "Invalid choice" ;;
        esac
        
        echo ""
        echo -e "${YELLOW}Press Enter to continue...${NC}"
        read < /dev/tty
    done
}

# Auto-reset menu
auto_reset_menu() {
    while true; do
        print_banner
        echo -e "${YELLOW}Automatic Reset${NC}"
        echo -e "${CYAN}Periodically restart paqet services for reliability${NC}"
        echo ""
        
        read_auto_reset_config
        
        # Show current status
        echo -e "${YELLOW}Current settings:${NC}"
        if [ "$ENABLED" = "true" ]; then
            echo -e "  Status:   ${GREEN}Enabled${NC}"
            echo -e "  Interval: ${CYAN}Every $INTERVAL $UNIT(s)${NC}"
            if systemctl is-active --quiet ${AUTO_RESET_TIMER}.timer 2>/dev/null; then
                echo -e "  Timer:    ${GREEN}Active${NC}"
            else
                echo -e "  Timer:    ${RED}Inactive${NC}"
            fi
        else
            echo -e "  Status:   ${RED}Disabled${NC}"
        fi
        echo ""
        
        echo -e "${YELLOW}Options:${NC}"
        echo ""
        echo -e "  ${CYAN}1)${NC} Enable automatic reset"
        echo -e "  ${CYAN}2)${NC} Disable automatic reset"
        echo -e "  ${CYAN}3)${NC} Set reset interval"
        echo -e "  ${CYAN}4)${NC} Manual reset now (restart all tunnels)"
        echo -e "  ${CYAN}0)${NC} Back to main menu"
        echo ""
        
        read -p "Choice: " reset_choice < /dev/tty
        
        case $reset_choice in
            1)
                echo ""
                if [ "$ENABLED" = "true" ]; then
                    print_info "Automatic reset is already enabled"
                else
                    # Use existing interval or default
                    read_auto_reset_config
                    write_auto_reset_config "true" "${INTERVAL:-6}" "${UNIT:-hour}"
                    create_auto_reset_timer "${INTERVAL:-6}" "${UNIT:-hour}"
                fi
                ;;
            2)
                echo ""
                if [ "$ENABLED" != "true" ]; then
                    print_info "Automatic reset is already disabled"
                else
                    write_auto_reset_config "false" "$INTERVAL" "$UNIT"
                    remove_auto_reset_timer
                fi
                ;;
            3)
                echo ""
                echo -e "${CYAN}Set reset interval${NC}"
                echo ""
                echo -e "  ${YELLOW}1)${NC} Every 1 hour"
                echo -e "  ${YELLOW}2)${NC} Every 3 hours"
                echo -e "  ${YELLOW}3)${NC} Every 6 hours"
                echo -e "  ${YELLOW}4)${NC} Every 12 hours"
                echo -e "  ${YELLOW}5)${NC} Every 24 hours (1 day)"
                echo -e "  ${YELLOW}6)${NC} Every 7 days"
                echo ""
                read -p "Choice: " interval_choice < /dev/tty
                
                case $interval_choice in
                    1) new_interval=1; new_unit=hour ;;
                    2) new_interval=3; new_unit=hour ;;
                    3) new_interval=6; new_unit=hour ;;
                    4) new_interval=12; new_unit=hour ;;
                    5) new_interval=1; new_unit=day ;;
                    6) new_interval=7; new_unit=day ;;
                    *) print_error "Invalid choice"; new_interval=""; new_unit="" ;;
                esac
                
                if [ -n "$new_interval" ]; then
                    write_auto_reset_config "$ENABLED" "$new_interval" "$new_unit"
                    if [ "$ENABLED" = "true" ]; then
                        create_auto_reset_timer "$new_interval" "$new_unit"
                    fi
                    print_success "Interval set to every $new_interval $new_unit(s)"
                fi
                ;;
            4)
                manual_reset_all
                ;;
            0)
                return 0
                ;;
            *)
                print_error "Invalid choice"
                ;;
        esac
        
        echo ""
        echo -e "${YELLOW}Press Enter to continue...${NC}"
        read < /dev/tty
    done
}

#===============================================================================
# Maintenance Helpers (auto-tune retrofit)
#===============================================================================

upsert_transport_conn_value() {
    local config_file="$1"
    local conn_value="$2"

    if grep -Eq '^[[:space:]]*conn:[[:space:]]*[0-9]+' "$config_file"; then
        sed -i "s/^[[:space:]]*conn:[[:space:]]*[0-9][0-9]*/  conn: ${conn_value}/" "$config_file"
    else
        # Accept quoted or unquoted `protocol: kcp` (users may manually edit YAML style).
        sed -i "/^[[:space:]]*protocol:[[:space:]]*\"\\?kcp\"\\?\\([[:space:]]*#.*\\)\\?$/a\\  conn: ${conn_value}" "$config_file"
    fi
}

upsert_kcp_scalar_value() {
    local config_file="$1"
    local key="$2"
    local value="$3"
    local quote_style="$4" # "quoted" or "bare"
    local rendered="$value"

    if [ "$quote_style" = "quoted" ]; then
        rendered="\"${value}\""
    fi

    if grep -Eq "^[[:space:]]*${key}:" "$config_file"; then
        sed -i "s|^[[:space:]]*${key}:.*|    ${key}: ${rendered}|" "$config_file"
    else
        sed -i "/^[[:space:]]*kcp:/a\\    ${key}: ${rendered}" "$config_file"
    fi
}

remove_legacy_kcp_alias_keys() {
    local config_file="$1"

    # Remove legacy/alternate KCP key names that paqet does not use anymore.
    # Keeping only canonical keys avoids confusing "duplicate" values in configs.
    sed -i \
        -e '/^[[:space:]]*snd_wnd:[[:space:]]*/d' \
        -e '/^[[:space:]]*rcv_wnd:[[:space:]]*/d' \
        -e '/^[[:space:]]*data_shard:[[:space:]]*/d' \
        -e '/^[[:space:]]*parity_shard:[[:space:]]*/d' \
        "$config_file"
}

apply_auto_tune_to_config_file() {
    local config_file="$1"

    if [ ! -f "$config_file" ]; then
        return 1
    fi

    if ! grep -Eq '^[[:space:]]*protocol:[[:space:]]*"?kcp"?([[:space:]]*#.*)?$' "$config_file" 2>/dev/null; then
        return 1
    fi

    if ! grep -Eq '^[[:space:]]*kcp:' "$config_file"; then
        return 1
    fi

    load_active_profile_preset_defaults

    # If Behzad preset is active, keep this path aligned with the active preset model
    # (fixed profile, no PaqX CPU/RAM auto KCP tuning fields).
    if [ "$PROFILE_PRESET_NAME" = "behzad" ]; then
        apply_profile_preset_to_config_file "$config_file" "behzad"
        return $?
    fi

    upsert_transport_conn_value "$config_file" "$AUTO_TUNE_CONN"

    upsert_kcp_scalar_value "$config_file" "mode" "$DEFAULT_KCP_MODE" "quoted"
    upsert_kcp_scalar_value "$config_file" "nodelay" "1" "bare"
    upsert_kcp_scalar_value "$config_file" "interval" "10" "bare"
    upsert_kcp_scalar_value "$config_file" "resend" "2" "bare"
    upsert_kcp_scalar_value "$config_file" "nocongestion" "1" "bare"
    upsert_kcp_scalar_value "$config_file" "wdelay" "false" "bare"
    upsert_kcp_scalar_value "$config_file" "acknodelay" "true" "bare"
    upsert_kcp_scalar_value "$config_file" "mtu" "$PROFILE_PRESET_KCP_MTU" "bare"
    upsert_kcp_scalar_value "$config_file" "rcvwnd" "$AUTO_TUNE_RCVWND" "bare"
    upsert_kcp_scalar_value "$config_file" "sndwnd" "$AUTO_TUNE_SNDWND" "bare"
    upsert_kcp_scalar_value "$config_file" "block" "$PROFILE_PRESET_KCP_BLOCK" "quoted"
    upsert_kcp_scalar_value "$config_file" "smuxbuf" "$AUTO_TUNE_SMUXBUF" "bare"
    upsert_kcp_scalar_value "$config_file" "streambuf" "$AUTO_TUNE_STREAMBUF" "bare"
    upsert_kcp_scalar_value "$config_file" "dshard" "$DEFAULT_KCP_DSHARD" "bare"
    upsert_kcp_scalar_value "$config_file" "pshard" "$DEFAULT_KCP_PSHARD" "bare"
    remove_legacy_kcp_alias_keys "$config_file"

    return 0
}

apply_auto_tune_existing_configs() {
    print_banner
    echo -e "${YELLOW}Apply PaqX-style Auto Tuning (Existing Configs)${NC}"
    echo ""

    local configs
    configs=$(get_all_configs)
    if [ -z "$configs" ]; then
        print_error "No paqet configurations found"
        print_info "Run setup first"
        return 1
    fi

    calculate_auto_kcp_profile
    show_auto_kcp_profile

    if [ "$(get_current_profile_preset)" = "behzad" ]; then
        print_warning "Active preset is 'behzad': this action will apply the Behzad standalone KCP profile (not PaqX CPU/RAM tuning)."
        echo ""
    fi

    echo -e "${YELLOW}This will update existing KCP settings on this server:${NC}"
    echo -e "  - conn / mode / mtu"
    echo -e "  - window sizes (rcvwnd/sndwnd)"
    echo -e "  - PaqX-style KCP defaults (nodelay/acknodelay/FEC/buffers)"
    echo -e "  - MTU/block use the active profile preset baseline ($(get_current_profile_preset))"
    echo -e "  - Kernel sysctl optimization file (${OPTIMIZE_SYSCTL_FILE})"
    echo ""
    echo -e "${YELLOW}Note:${NC} Existing configs will be backed up as *.autotune.bak.<timestamp>"
    echo ""

    read_confirm "Apply auto tuning to all existing configs on this server?" do_apply "y"
    [ "$do_apply" != true ] && return 0

    local ts
    ts=$(date +%s)
    local updated=0
    local skipped=0
    local failed=0
    local updated_configs=""

    while IFS= read -r config_file; do
        [ -z "$config_file" ] && continue

        local name
        name=$(get_tunnel_name "$config_file")
        local backup_file="${config_file}.autotune.bak.${ts}"

        if ! cp "$config_file" "$backup_file" 2>/dev/null; then
            print_warning "Backup failed for ${name}; skipping (${config_file})"
            failed=$((failed + 1))
            continue
        fi

        if apply_auto_tune_to_config_file "$config_file"; then
            print_success "Updated KCP profile for '${name}'"
            updated=$((updated + 1))
            updated_configs="${updated_configs}${config_file}
"
        else
            print_warning "Skipped '${name}' (unsupported or invalid KCP config)"
            skipped=$((skipped + 1))
        fi
    done <<< "$configs"

    apply_paqx_kernel_optimizations

    echo ""
    print_info "Summary: updated=${updated}, skipped=${skipped}, failed=${failed}"

    if [ "$updated" -gt 0 ]; then
        echo ""
        read_confirm "Restart paqet services now to apply new KCP settings?" do_restart "y"
        if [ "$do_restart" = true ]; then
            while IFS= read -r config_file; do
                [ -z "$config_file" ] && continue
                local service
                service=$(get_tunnel_service "$config_file")
                if systemctl cat "$service" >/dev/null 2>&1; then
                    if systemctl restart "$service" >/dev/null 2>&1; then
                        print_success "Restarted $service"
                    else
                        print_warning "Failed to restart $service (check logs)"
                    fi
                fi
            done <<< "$updated_configs"
        else
            print_warning "Services not restarted. Restart them manually to apply changes."
        fi
    fi
}

#===============================================================================
# Profile Preset Helpers (separate from PaqX auto-tune)
#===============================================================================

upsert_transport_scalar_value() {
    local config_file="$1"
    local key="$2"
    local value="$3"

    if grep -Eq "^[[:space:]]*${key}:" "$config_file"; then
        sed -i "s|^[[:space:]]*${key}:.*|  ${key}: ${value}|" "$config_file"
    else
        sed -i "/^[[:space:]]*transport:[[:space:]]*$/a\\  ${key}: ${value}" "$config_file"
    fi
}

remove_transport_scalar_value() {
    local config_file="$1"
    local key="$2"
    sed -i "/^[[:space:]]*${key}:[[:space:]]*/d" "$config_file"
}

upsert_or_remove_network_pcap_sockbuf() {
    local config_file="$1"
    local sockbuf_value="$2"
    local tmp_file="${config_file}.pcap.$$"

    awk -v sockbuf="$sockbuf_value" '
        function print_pcap_block() {
            print "  pcap:"
            print "    sockbuf: " sockbuf
        }
        {
            line = $0

            if (!in_network && line ~ /^network:[[:space:]]*$/) {
                in_network = 1
                print line
                next
            }

            if (in_network) {
                if (in_pcap) {
                    if (line ~ /^    /) {
                        next
                    }
                    in_pcap = 0
                }

                if (line ~ /^  pcap:[[:space:]]*$/) {
                    replaced_or_inserted = 1
                    if (sockbuf != "") {
                        print_pcap_block()
                    }
                    in_pcap = 1
                    next
                }

                if (line ~ /^[^[:space:]]/) {
                    if (!replaced_or_inserted && sockbuf != "") {
                        print_pcap_block()
                        replaced_or_inserted = 1
                    }
                    in_network = 0
                    print line
                    next
                }

                print line
                next
            }

            print line
        }
        END {
            if (in_network && !replaced_or_inserted && sockbuf != "") {
                print_pcap_block()
            }
        }
    ' "$config_file" > "$tmp_file" && mv "$tmp_file" "$config_file"
}

apply_profile_preset_to_config_file() {
    local config_file="$1"
    local preset="${2:-$(get_current_profile_preset)}"

    if [ ! -f "$config_file" ]; then
        return 1
    fi

    if ! grep -Eq '^[[:space:]]*protocol:[[:space:]]*"?kcp"?([[:space:]]*#.*)?$' "$config_file" 2>/dev/null; then
        return 1
    fi

    if ! grep -Eq '^[[:space:]]*kcp:' "$config_file"; then
        return 1
    fi

    load_active_profile_preset_defaults "$preset"

    # Profile switch is intentionally limited to tuning-related sections only.
    # It does NOT touch forward ports, tunnel/server ports, server IPs, or bind IPs.
    upsert_kcp_scalar_value "$config_file" "mode" "$DEFAULT_KCP_MODE" "quoted"

    if [ "$PROFILE_PRESET_NAME" = "behzad" ]; then
        upsert_transport_conn_value "$config_file" "4"
        remove_paqx_kcp_tuning_keys "$config_file"
    else
        # Apply the PaqX auto-tune profile deterministically for the default preset,
        # even if the current active preset was changed just before this call.
        calculate_paqx_auto_kcp_profile
        upsert_transport_conn_value "$config_file" "$AUTO_TUNE_CONN"
        upsert_kcp_scalar_value "$config_file" "nodelay" "1" "bare"
        upsert_kcp_scalar_value "$config_file" "interval" "10" "bare"
        upsert_kcp_scalar_value "$config_file" "resend" "2" "bare"
        upsert_kcp_scalar_value "$config_file" "nocongestion" "1" "bare"
        upsert_kcp_scalar_value "$config_file" "wdelay" "false" "bare"
        upsert_kcp_scalar_value "$config_file" "acknodelay" "true" "bare"
        upsert_kcp_scalar_value "$config_file" "rcvwnd" "$AUTO_TUNE_RCVWND" "bare"
        upsert_kcp_scalar_value "$config_file" "sndwnd" "$AUTO_TUNE_SNDWND" "bare"
        upsert_kcp_scalar_value "$config_file" "smuxbuf" "$AUTO_TUNE_SMUXBUF" "bare"
        upsert_kcp_scalar_value "$config_file" "streambuf" "$AUTO_TUNE_STREAMBUF" "bare"
        upsert_kcp_scalar_value "$config_file" "dshard" "$DEFAULT_KCP_DSHARD" "bare"
        upsert_kcp_scalar_value "$config_file" "pshard" "$DEFAULT_KCP_PSHARD" "bare"
    fi

    upsert_kcp_scalar_value "$config_file" "block" "$PROFILE_PRESET_KCP_BLOCK" "quoted"
    upsert_kcp_scalar_value "$config_file" "mtu" "$PROFILE_PRESET_KCP_MTU" "bare"

    if [ -n "$PROFILE_PRESET_TRANSPORT_TCPBUF" ]; then
        upsert_transport_scalar_value "$config_file" "tcpbuf" "$PROFILE_PRESET_TRANSPORT_TCPBUF"
    else
        remove_transport_scalar_value "$config_file" "tcpbuf"
    fi

    if [ -n "$PROFILE_PRESET_TRANSPORT_UDPBUF" ]; then
        upsert_transport_scalar_value "$config_file" "udpbuf" "$PROFILE_PRESET_TRANSPORT_UDPBUF"
    else
        remove_transport_scalar_value "$config_file" "udpbuf"
    fi

    local role=""
    role=$(grep '^role:' "$config_file" 2>/dev/null | awk '{print $2}' | tr -d '"')
    local pcap_sockbuf=""
    if [ "$role" = "server" ]; then
        pcap_sockbuf="$PROFILE_PRESET_PCAP_SOCKBUF_SERVER"
    else
        pcap_sockbuf="$PROFILE_PRESET_PCAP_SOCKBUF_CLIENT"
    fi
    upsert_or_remove_network_pcap_sockbuf "$config_file" "$pcap_sockbuf"
    remove_legacy_kcp_alias_keys "$config_file"

    return 0
}

apply_active_profile_preset_existing_configs() {
    print_banner
    local active_preset
    active_preset=$(get_current_profile_preset)
    load_active_profile_preset_defaults "$active_preset"

    echo -e "${YELLOW}Apply Active Profile Preset (Existing Configs)${NC}"
    echo ""
    echo -e "  ${YELLOW}Preset:${NC} ${CYAN}${PROFILE_PRESET_NAME}${NC} (${PROFILE_PRESET_LABEL})"
    echo -e "  ${YELLOW}Changes:${NC}"
    echo -e "    - KCP block: ${CYAN}${PROFILE_PRESET_KCP_BLOCK}${NC}"
    echo -e "    - KCP MTU:   ${CYAN}${PROFILE_PRESET_KCP_MTU}${NC}"
    if [ -n "$PROFILE_PRESET_TRANSPORT_TCPBUF" ] || [ -n "$PROFILE_PRESET_TRANSPORT_UDPBUF" ]; then
        echo -e "    - transport.tcpbuf / udpbuf: ${CYAN}${PROFILE_PRESET_TRANSPORT_TCPBUF:-default}/${PROFILE_PRESET_TRANSPORT_UDPBUF:-default}${NC}"
    else
        echo -e "    - transport.tcpbuf / udpbuf: ${CYAN}removed (use paqet defaults)${NC}"
    fi
    if [ -n "$PROFILE_PRESET_PCAP_SOCKBUF_SERVER" ] || [ -n "$PROFILE_PRESET_PCAP_SOCKBUF_CLIENT" ]; then
        echo -e "    - network.pcap.sockbuf: ${CYAN}role-based preset values${NC}"
    else
        echo -e "    - network.pcap.sockbuf: ${CYAN}removed (use paqet defaults)${NC}"
    fi
    if [ "$PROFILE_PRESET_NAME" = "behzad" ]; then
        echo -e "    - KCP conn: ${CYAN}fixed Behzad preset (4)${NC}"
        echo -e "    - PaqX KCP auto-tune fields: ${CYAN}removed (no mixing)${NC}"
    else
        echo -e "    - KCP conn/windows/FEC/smux: ${CYAN}PaqX CPU/RAM auto-tune${NC}"
    fi
    echo ""
    echo -e "${CYAN}Ports and IP addresses are NOT changed. Only profile/tuning settings are updated.${NC}"
    print_warning "Apply the same transport/KCP profile on BOTH tunnel ends to keep them compatible."
    echo ""

    local configs
    configs=$(get_all_configs)
    if [ -z "$configs" ]; then
        print_error "No paqet configurations found"
        print_info "Run setup first"
        return 1
    fi

    read_confirm "Apply active profile preset to all existing configs on this server?" do_apply "y"
    [ "$do_apply" != true ] && return 0

    local ts
    ts=$(date +%s)
    local updated=0
    local skipped=0
    local failed=0
    local updated_configs=""

    while IFS= read -r config_file; do
        [ -z "$config_file" ] && continue

        local name
        name=$(get_tunnel_name "$config_file")
        local backup_file="${config_file}.profilepreset.bak.${ts}"

        if ! cp "$config_file" "$backup_file" 2>/dev/null; then
            print_warning "Backup failed for ${name}; skipping (${config_file})"
            failed=$((failed + 1))
            continue
        fi

        if apply_profile_preset_to_config_file "$config_file" "$active_preset"; then
            print_success "Applied profile preset to '${name}'"
            updated=$((updated + 1))
            updated_configs="${updated_configs}${config_file}
"
        else
            print_warning "Skipped '${name}' (unsupported or invalid KCP config)"
            skipped=$((skipped + 1))
        fi
    done <<< "$configs"

    echo ""
    print_info "Summary: updated=${updated}, skipped=${skipped}, failed=${failed}"

    if [ "$updated" -gt 0 ]; then
        echo ""
        read_confirm "Restart paqet services now to apply profile preset changes?" do_restart "y"
        if [ "$do_restart" = true ]; then
            while IFS= read -r config_file; do
                [ -z "$config_file" ] && continue
                local service
                service=$(get_tunnel_service "$config_file")
                if systemctl cat "$service" >/dev/null 2>&1; then
                    if systemctl restart "$service" >/dev/null 2>&1; then
                        print_success "Restarted $service"
                    else
                        print_warning "Failed to restart $service (check logs)"
                    fi
                fi
            done <<< "$updated_configs"
        else
            print_warning "Services not restarted. Restart them manually to apply changes."
        fi
    fi
}

#===============================================================================
# Core Updater + Auto-Updater
#===============================================================================

create_paqet_core_backup() {
    local reason="${1:-manual}"

    if [ ! -f "$PAQET_BIN" ]; then
        return 1
    fi

    local ts
    ts=$(date +%s)
    local backup_bin="${PAQET_BIN}.corebak.${ts}.${reason}"
    cp "$PAQET_BIN" "$backup_bin" || return 1
    chmod +x "$backup_bin" 2>/dev/null || true

    local current_provider
    current_provider=$(get_current_core_provider)
    cat > "${backup_bin}.meta" << EOF
# paqet core binary backup metadata
CORE_PROVIDER="${current_provider}"
BACKUP_REASON="${reason}"
CREATED_AT="$(date -Iseconds 2>/dev/null || date)"
EOF

    echo "$backup_bin"
    return 0
}

list_paqet_core_backups() {
    find "$PAQET_DIR" -maxdepth 1 -type f \( -name 'paqet.corebak.*' -o -name 'paqet.bak.*' \) ! -name '*.meta' 2>/dev/null \
        | while IFS= read -r f; do
            [ -f "$f" ] || continue
            printf '%s\t%s\n' "$(stat -c %Y "$f" 2>/dev/null || echo 0)" "$f"
        done \
        | sort -rn | cut -f2-
    return 0
}

restore_paqet_core_backup_file() {
    local backup_file="$1"
    [ -f "$backup_file" ] || { print_error "Backup file not found: $backup_file"; return 1; }

    # Avoid "Text file busy" by replacing through a temp file + rename.
    local tmp_restore="${PAQET_BIN}.restore.$$"
    cp "$backup_file" "$tmp_restore" || return 1
    chmod +x "$tmp_restore" 2>/dev/null || true
    mv -f "$tmp_restore" "$PAQET_BIN" || {
        rm -f "$tmp_restore" 2>/dev/null || true
        return 1
    }

    local meta_file="${backup_file}.meta"
    if [ -f "$meta_file" ]; then
        local backup_provider=""
        backup_provider=$(grep '^CORE_PROVIDER=' "$meta_file" 2>/dev/null | head -1 | cut -d'"' -f2)
        if [ -n "$backup_provider" ]; then
            read_confirm "Restore core provider metadata to '${backup_provider}' too?" restore_meta "y"
            if [ "$restore_meta" = true ]; then
                set_current_core_provider "$backup_provider"
                print_info "Core provider metadata restored to: $(get_core_provider_label "$backup_provider")"
            fi
        fi
    fi

    return 0
}

show_core_management_status() {
    local provider
    provider=$(get_current_core_provider)
    local profile_preset
    profile_preset=$(get_current_profile_preset)
    local core_ver
    core_ver=$(get_installed_paqet_version_text)

    echo -e "  ${YELLOW}Core Provider:${NC}  ${CYAN}$(get_core_provider_label "$provider")${NC}"
    echo -e "  ${YELLOW}Core Version:${NC}   ${CYAN}${core_ver}${NC}"
    echo -e "  ${YELLOW}Profile Preset:${NC} ${CYAN}${profile_preset}${NC} ($(get_profile_preset_label "$profile_preset"))"
}

switch_paqet_core_provider() {
    local target_provider="$1"
    local target_label
    target_label=$(get_core_provider_label "$target_provider")
    local current_provider
    current_provider=$(get_current_core_provider)

    print_banner
    echo -e "${YELLOW}Switch paqet Core Provider${NC}"
    echo ""
    echo -e "  ${YELLOW}Current:${NC} ${CYAN}$(get_core_provider_label "$current_provider")${NC}"
    echo -e "  ${YELLOW}Target:${NC}  ${CYAN}${target_label}${NC}"
    echo ""
    echo -e "${CYAN}This replaces only the paqet binary (core). Your configs/services remain the same.${NC}"
    echo -e "${CYAN}A backup of the current binary will be created before switching.${NC}"
    print_warning "Core protocol compatibility may differ between providers/versions."
    print_warning "Switch both tunnel ends to compatible cores (or rollback) if connections drop."
    echo ""

    read_confirm "Switch core provider now and restart services?" do_switch "y"
    [ "$do_switch" != true ] && return 0

    local backup_bin=""
    if [ -f "$PAQET_BIN" ]; then
        backup_bin=$(create_paqet_core_backup "switch-${target_provider}") || {
            print_error "Failed to create core backup"
            return 1
        }
        print_info "Backup created: $backup_bin"
    else
        print_info "No existing paqet binary found; provider will be set after install"
    fi

    local old_provider="$current_provider"
    PAQET_CORE_PROVIDER_OVERRIDE="$target_provider"

    if download_paqet; then
        unset PAQET_CORE_PROVIDER_OVERRIDE
        set_current_core_provider "$target_provider"
        restart_paqet_services_after_core_update
        print_success "Core provider switched to: $(get_core_provider_label "$target_provider")"
        return 0
    fi

    unset PAQET_CORE_PROVIDER_OVERRIDE
    print_error "Core provider switch failed"
    if [ -n "$backup_bin" ] && [ -f "$backup_bin" ]; then
        if restore_paqet_core_backup_file "$backup_bin"; then
            print_warning "Restored previous paqet binary from backup"
        fi
    fi
    set_current_core_provider "$old_provider"
    return 1
}

set_profile_preset_interactive() {
    local target_preset="$1"
    load_active_profile_preset_defaults "$target_preset"

    print_banner
    echo -e "${YELLOW}Switch Profile Preset${NC}"
    echo ""
    echo -e "  ${YELLOW}Target preset:${NC} ${CYAN}${PROFILE_PRESET_NAME}${NC} (${PROFILE_PRESET_LABEL})"
    echo -e "  ${YELLOW}KCP block:${NC}     ${CYAN}${PROFILE_PRESET_KCP_BLOCK}${NC}"
    echo -e "  ${YELLOW}KCP MTU:${NC}       ${CYAN}${PROFILE_PRESET_KCP_MTU}${NC}"
    echo -e "  ${YELLOW}tcpbuf/udpbuf:${NC} ${CYAN}${PROFILE_PRESET_TRANSPORT_TCPBUF:-default}/${PROFILE_PRESET_TRANSPORT_UDPBUF:-default}${NC}"
    if [ -n "$PROFILE_PRESET_PCAP_SOCKBUF_SERVER" ] || [ -n "$PROFILE_PRESET_PCAP_SOCKBUF_CLIENT" ]; then
        echo -e "  ${YELLOW}pcap.sockbuf:${NC}  ${CYAN}server=${PROFILE_PRESET_PCAP_SOCKBUF_SERVER}, client=${PROFILE_PRESET_PCAP_SOCKBUF_CLIENT}${NC}"
    else
        echo -e "  ${YELLOW}pcap.sockbuf:${NC}  ${CYAN}use paqet defaults${NC}"
    fi
    echo ""
    echo -e "${CYAN}This only changes the active profile preset metadata for future setups.${NC}"
    echo -e "${CYAN}Use the apply option to retrofit the preset to existing configs.${NC}"
    echo -e "${CYAN}Profile apply keeps ports and IP addresses unchanged (tuning fields only).${NC}"
    print_warning "KCP profile values (especially block/MTU) should match on BOTH tunnel ends."
    print_warning "Applying a preset on only one side can cause connection loss until the peer is updated."
    echo ""

    read_confirm "Set active profile preset to '${target_preset}'?" do_set "y"
    [ "$do_set" != true ] && return 0

    set_current_profile_preset "$target_preset"
    print_success "Active profile preset is now: $target_preset"

    echo ""
    read_confirm "Apply this profile preset to existing configs now?" do_apply_now "n"
    if [ "$do_apply_now" = true ]; then
        apply_active_profile_preset_existing_configs
    fi
}

rollback_paqet_core_menu() {
    print_banner
    echo -e "${YELLOW}Rollback paqet Core Binary${NC}"
    echo ""

    local backups
    backups=$(list_paqet_core_backups)
    if [ -z "$backups" ]; then
        print_error "No paqet core backups found"
        return 1
    fi

    local idx=0
    local backup_array=()
    while IFS= read -r b; do
        [ -z "$b" ] && continue
        idx=$((idx + 1))
        backup_array+=("$b")
        echo -e "  ${CYAN}${idx})${NC} ${YELLOW}$b${NC}"
    done <<< "$backups"

    echo ""
    read -p "Select backup to restore (0 to cancel): " rollback_choice < /dev/tty
    if [ "$rollback_choice" = "0" ]; then
        return 0
    fi
    if ! [[ "$rollback_choice" =~ ^[0-9]+$ ]] || [ "$rollback_choice" -lt 1 ] || [ "$rollback_choice" -gt "${#backup_array[@]}" ]; then
        print_error "Invalid choice"
        return 1
    fi

    local selected_backup="${backup_array[$((rollback_choice - 1))]}"
    echo ""
    read_confirm "Restore selected backup and restart services?" do_restore "y"
    [ "$do_restore" != true ] && return 0

    if restore_paqet_core_backup_file "$selected_backup"; then
        restart_paqet_services_after_core_update
        print_success "Core rollback completed"
        return 0
    fi

    print_error "Core rollback failed"
    return 1
}

core_management_menu() {
    while true; do
        print_banner
        echo -e "${YELLOW}Core & Profile Management${NC}"
        echo ""
        show_core_management_status
        echo ""
        echo -e "${CYAN}Profile apply updates tuning fields only and keeps ports/IP addresses unchanged.${NC}"
        echo ""
        echo -e "  ${CYAN}1)${NC} Switch Core -> Official (hanselime/paqet)"
        echo -e "  ${CYAN}2)${NC} Switch Core -> Behzad Optimized (PaqetOptimized)"
        echo -e "  ${CYAN}3)${NC} Rollback Core Binary from Backup"
        echo -e "  ${CYAN}4)${NC} Set Profile Preset -> Default"
        echo -e "  ${CYAN}5)${NC} Set Profile Preset -> Behzad"
        echo -e "  ${CYAN}6)${NC} Apply Active Profile Preset to Existing Configs"
        echo -e "  ${CYAN}7)${NC} View Active KCP Profile Preview (read-only)"
        echo -e "  ${CYAN}8)${NC} Show Effective Port/Profile Defaults"
        echo -e "  ${CYAN}0)${NC} Back"
        echo ""
        read -p "Choice: " core_choice < /dev/tty

        case "$core_choice" in
            1) switch_paqet_core_provider "official" ;;
            2) switch_paqet_core_provider "behzad-optimized" ;;
            3) rollback_paqet_core_menu ;;
            4) set_profile_preset_interactive "default" ;;
            5) set_profile_preset_interactive "behzad" ;;
            6) apply_active_profile_preset_existing_configs ;;
            7) view_current_auto_profile ;;
            8) show_port_config ;;
            0) return 0 ;;
            *) print_error "Invalid choice" ;;
        esac

        echo ""
        echo -e "${YELLOW}Press Enter to continue...${NC}"
        read < /dev/tty
    done
}

get_latest_paqet_release_tag() {
    get_latest_paqet_release_tag_for_provider "official"
}

get_installed_paqet_version_text() {
    if [ ! -x "$PAQET_BIN" ]; then
        echo "not installed"
        return 0
    fi

    local out=""
    out=$("$PAQET_BIN" version 2>/dev/null | head -1) || true
    [ -z "$out" ] && out=$("$PAQET_BIN" --version 2>/dev/null | head -1) || true
    [ -z "$out" ] && out=$("$PAQET_BIN" -v 2>/dev/null | head -1) || true

    if [ -n "$out" ]; then
        echo "$out"
    else
        echo "installed (version output unavailable)"
    fi
}

restart_paqet_services_after_core_update() {
    print_step "Restarting paqet services..."

    local configs=$(get_all_configs)
    local restarted=0
    local failed=0

    if [ -n "$configs" ]; then
        while IFS= read -r config_file; do
            [ -z "$config_file" ] && continue
            local service=$(get_tunnel_service "$config_file")
            if systemctl cat "$service" >/dev/null 2>&1; then
                if systemctl restart "$service" >/dev/null 2>&1; then
                    print_success "Restarted $service"
                    restarted=$((restarted + 1))
                else
                    print_warning "Failed to restart $service (check: journalctl -u $service -n 50)"
                    failed=$((failed + 1))
                fi
            fi
        done <<< "$configs"
    elif systemctl cat paqet >/dev/null 2>&1; then
        if systemctl restart paqet >/dev/null 2>&1; then
            print_success "Restarted paqet"
            restarted=1
        else
            print_warning "Failed to restart paqet (check: journalctl -u paqet -n 50)"
            failed=1
        fi
    fi

    if [ "$restarted" -eq 0 ] && [ "$failed" -eq 0 ]; then
        print_info "No installed paqet services detected to restart"
    fi
}

update_paqet_core() {
    print_banner
    echo -e "${YELLOW}Update paqet Core Binary${NC}"
    echo ""

    local provider
    provider=$(get_current_core_provider)
    print_info "Core provider: ${CYAN}$(get_core_provider_label "$provider")${NC}"

    local installed_ver
    installed_ver=$(get_installed_paqet_version_text)
    print_info "Installed core: ${CYAN}${installed_ver}${NC}"

    local latest_tag
    latest_tag=$(get_latest_paqet_release_tag_for_provider "$provider")
    if [ -n "$latest_tag" ]; then
        print_info "Latest provider release/tag: ${CYAN}${latest_tag}${NC}"
    else
        print_warning "Could not fetch latest release tag (network may be restricted)"
    fi
    local installed_meta_provider=""
    local installed_meta_version=""
    installed_meta_provider=$(get_installed_core_meta_field "CORE_PROVIDER")
    installed_meta_version=$(get_installed_core_meta_field "CORE_VERSION")
    if [ -n "$latest_tag" ] && [ "$installed_meta_provider" = "$provider" ] && [ "$installed_meta_version" = "$latest_tag" ]; then
        print_success "Installed core already matches the latest provider release/tag (${latest_tag})."
        print_info "No download needed. Cached core archives remain available for future switches/rollbacks."
        return 0
    fi
    print_warning "Core updates may require updating the peer server too if protocol compatibility changes."
    echo ""

    read_confirm "Download latest core for current provider and restart services?" do_core_update "y"
    [ "$do_core_update" != true ] && return 0

    mkdir -p "$PAQET_DIR"

    local backup_bin=""
    if [ -f "$PAQET_BIN" ]; then
        backup_bin=$(create_paqet_core_backup "update-${provider}") || {
            print_error "Failed to create core backup"
            return 1
        }
        print_info "Backup created: $backup_bin"
    fi

    local old_version_setting="$PAQET_VERSION"
    PAQET_VERSION="latest"

    if download_paqet; then
        PAQET_VERSION="$old_version_setting"
        restart_paqet_services_after_core_update
        print_success "paqet core update completed"
    else
        PAQET_VERSION="$old_version_setting"
        print_error "paqet core update failed"
        if [ -n "$backup_bin" ] && [ -f "$backup_bin" ]; then
            local tmp_restore="${PAQET_BIN}.restorefail.$$"
            if cp "$backup_bin" "$tmp_restore" 2>/dev/null && chmod +x "$tmp_restore" 2>/dev/null && mv -f "$tmp_restore" "$PAQET_BIN" 2>/dev/null; then
                print_warning "Restored previous paqet binary from backup"
            else
                rm -f "$tmp_restore" 2>/dev/null || true
                print_warning "Failed to restore previous paqet binary automatically (manual restore may be required)"
            fi
        fi
        return 1
    fi
}

check_for_updates() {
    print_banner
    echo -e "${YELLOW}Checking for Updates${NC}"
    echo ""
    
    print_step "Current version: ${CYAN}$INSTALLER_VERSION${NC}"
    echo ""
    
    print_step "Fetching latest version from GitHub..."
    
    # Get latest version from GitHub
    local latest_version=""
    local release_info=""
    local raw_script=""
    
    # Method 1: Try GitHub releases API
    release_info=$(curl -s --max-time 10 "https://api.github.com/repos/${INSTALLER_REPO}/releases/latest" 2>/dev/null)
    if [ -n "$release_info" ]; then
        latest_version=$(echo "$release_info" | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')
    fi
    
    # Method 2: If no release found, fetch from raw main branch
    if [ -z "$latest_version" ]; then
        print_info "No releases found, checking main branch..."
        raw_script=$(curl -s --max-time 15 "https://raw.githubusercontent.com/${INSTALLER_REPO}/main/install.sh" 2>/dev/null)
        if [ -n "$raw_script" ]; then
            latest_version=$(echo "$raw_script" | grep 'INSTALLER_VERSION=' | head -1 | cut -d'"' -f2)
        fi
    fi
    
    if [ -z "$latest_version" ]; then
        print_error "Could not fetch version information"
        print_info "This may be due to network restrictions"
        echo ""
        echo -e "${YELLOW}Manual update:${NC}"
        echo -e "  ${CYAN}bash <(curl -fsSL https://raw.githubusercontent.com/${INSTALLER_REPO}/main/install.sh)${NC}"
        return 1
    fi
    
    print_info "Latest version: ${CYAN}$latest_version${NC}"
    echo ""
    
    # Compare versions (simple string comparison)
    if [ "$INSTALLER_VERSION" = "$latest_version" ]; then
        echo ""
        echo -e "${YELLOW}Check out my latest tunnel project (SMTP-based):${NC}"
        echo -e "  ${CYAN}https://github.com/g3ntrix/smtp-tunnel${NC}"
        echo ""
        print_success "You are running the latest version!"
        return 0
    fi
    
    # Version is different (could be newer or older)
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}A new version is available!${NC}"
    echo -e "  Current: ${RED}$INSTALLER_VERSION${NC}"
    echo -e "  Latest:  ${GREEN}$latest_version${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    read_confirm "Would you like to update now?" do_update "y"
    
    if [ "$do_update" = true ]; then
        update_installer
    fi
}

update_installer() {
    print_step "Downloading latest installer..."
    
    local temp_script="/tmp/paqet_install_new.sh"
    local download_url="https://raw.githubusercontent.com/${INSTALLER_REPO}/main/install.sh"
    
    if curl -fsSL "$download_url" -o "$temp_script" 2>/dev/null; then
        chmod +x "$temp_script"
        
        # Verify the downloaded script
        if grep -q "INSTALLER_VERSION" "$temp_script"; then
            local new_version=$(grep '^INSTALLER_VERSION=' "$temp_script" | cut -d'"' -f2)
            print_success "Downloaded version: $new_version"
            
            # Backup current configs if they exist
            local backup_configs=$(get_all_configs 2>/dev/null)
            if [ -n "$backup_configs" ]; then
                while IFS= read -r cfg; do
                    cp "$cfg" "${cfg}.backup"
                done <<< "$backup_configs"
                print_info "Configurations backed up"
            fi
            
            # Update the installed command if it exists
            if is_command_installed; then
                cp "$temp_script" "$INSTALLER_CMD"
                chmod +x "$INSTALLER_CMD"
                print_success "Updated paqet-tunnel command at $INSTALLER_CMD"
            fi
            
            echo ""
            echo -e "${YELLOW}Check out my latest tunnel project (SMTP-based):${NC}"
            echo -e "  ${CYAN}https://github.com/g3ntrix/smtp-tunnel${NC}"
            echo ""
            print_step "Launching updated installer..."
            echo ""
            
            # Execute the new script
            exec bash "$temp_script"
        else
            print_error "Downloaded file doesn't appear to be valid"
            rm -f "$temp_script"
            return 1
        fi
    else
        print_error "Failed to download update"
        print_info "Network may be restricted. Try manual update:"
        echo -e "  ${CYAN}bash <(curl -fsSL $download_url)${NC}"
        return 1
    fi
}

#===============================================================================
# Update Menu + Read-only Auto Profile + Quick Port Configuration Display
#===============================================================================

updates_menu() {
    while true; do
        print_banner
        echo -e "${YELLOW}Updates${NC}"
        echo ""

        local core_ver
        core_ver=$(get_installed_paqet_version_text)
        local core_provider
        core_provider=$(get_current_core_provider)
        local profile_preset
        profile_preset=$(get_current_profile_preset)
        echo -e "  ${YELLOW}Installer:${NC}   ${CYAN}${INSTALLER_VERSION}${NC}"
        echo -e "  ${YELLOW}paqet Core:${NC}  ${CYAN}${core_ver}${NC}"
        echo -e "  ${YELLOW}Provider:${NC}    ${CYAN}$(get_core_provider_label "$core_provider")${NC}"
        echo -e "  ${YELLOW}Profile:${NC}     ${CYAN}${profile_preset}${NC} ($(get_profile_preset_label "$profile_preset"))"
        echo ""

        echo -e "  ${CYAN}1)${NC} Check/Update Installer Script"
        echo -e "  ${CYAN}2)${NC} Update paqet Core (binary)"
        echo -e "  ${CYAN}3)${NC} Core & Profile Management"
        echo -e "  ${CYAN}0)${NC} Back"
        echo ""
        read -p "Choice: " upd_choice < /dev/tty

        case $upd_choice in
            1) check_for_updates ;;
            2) update_paqet_core ;;
            3) core_management_menu ;;
            0) return 0 ;;
            *) print_error "Invalid choice" ;;
        esac

        echo ""
        echo -e "${YELLOW}Press Enter to continue...${NC}"
        read < /dev/tty
    done
}

view_current_auto_profile() {
    print_banner
    echo -e "${YELLOW}Active KCP Profile Preview (Read-only)${NC}"
    echo ""
    calculate_auto_kcp_profile
    show_auto_kcp_profile
    echo -e "${CYAN}No changes were applied. This only shows the effective KCP profile for this server.${NC}"
    echo -e "${CYAN}To apply it to existing configs, use: Updates -> Core & Profile Management -> Apply Active Profile Preset to Existing Configs.${NC}"
    echo ""
}

show_port_config() {
    load_active_profile_preset_defaults
    echo ""
    echo -e "${MAGENTA}════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}              Current Port Configuration                    ${NC}"
    echo -e "${MAGENTA}════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${YELLOW}Default paqet port:${NC}     ${CYAN}$DEFAULT_PAQET_PORT${NC}"
    echo -e "  ${YELLOW}Default forward ports:${NC}  ${CYAN}$DEFAULT_FORWARD_PORTS${NC}"
    echo -e "  ${YELLOW}Profile preset:${NC}         ${CYAN}${PROFILE_PRESET_NAME}${NC} (${PROFILE_PRESET_LABEL})"
    echo -e "  ${YELLOW}KCP mode:${NC}               ${CYAN}$DEFAULT_KCP_MODE${NC}"
    if [ "$PROFILE_PRESET_NAME" = "behzad" ]; then
        echo -e "  ${YELLOW}KCP connections:${NC}        ${CYAN}4${NC} (Behzad preset fixed value)"
    else
        echo -e "  ${YELLOW}KCP connections:${NC}        ${CYAN}$DEFAULT_KCP_CONN${NC} (PaqX CPU/RAM auto-tuned on setup)"
    fi
    echo -e "  ${YELLOW}KCP MTU:${NC}                ${CYAN}${PROFILE_PRESET_KCP_MTU}${NC} (effective baseline)"
    echo -e "  ${YELLOW}KCP block:${NC}              ${CYAN}${PROFILE_PRESET_KCP_BLOCK}${NC}"
    if [ -n "$PROFILE_PRESET_TRANSPORT_TCPBUF" ] || [ -n "$PROFILE_PRESET_TRANSPORT_UDPBUF" ]; then
        echo -e "  ${YELLOW}tcpbuf/udpbuf:${NC}          ${CYAN}${PROFILE_PRESET_TRANSPORT_TCPBUF:-default}/${PROFILE_PRESET_TRANSPORT_UDPBUF:-default}${NC}"
    else
        echo -e "  ${YELLOW}tcpbuf/udpbuf:${NC}          ${CYAN}use paqet defaults${NC}"
    fi
    echo -e "${MAGENTA}════════════════════════════════════════════════════════════${NC}"
    echo ""
    if [ "$PROFILE_PRESET_NAME" = "behzad" ]; then
        echo -e "${CYAN}Setup applies the active Behzad preset as a standalone profile (no PaqX KCP auto-tune mixing) + kernel sysctl optimization.${NC}"
    else
        echo -e "${CYAN}Setup applies the active profile preset + PaqX-style CPU/RAM auto tuning (conn + wnd) + kernel sysctl optimization.${NC}"
    fi
    echo -e "${CYAN}Use Maintenance -> 'd' if you need to lower MTU to 1280 on restrictive networks.${NC}"
    echo ""
}

#===============================================================================
# Install/Uninstall Script as Command
#===============================================================================

install_command() {
    print_step "Installing paqet-tunnel command..."
    
    # Download latest script from GitHub
    local temp_script="/tmp/paqet-tunnel-install.sh"
    local download_url="https://raw.githubusercontent.com/${INSTALLER_REPO}/main/install.sh"
    
    # Check if we're running from the installed location
    if [ -f "$INSTALLER_CMD" ]; then
        # Already installed, just update
        print_info "Updating existing installation..."
    fi
    
    # Try to download latest version
    if curl -fsSL "$download_url" -o "$temp_script" 2>/dev/null; then
        chmod +x "$temp_script"
        mv "$temp_script" "$INSTALLER_CMD"
        print_success "paqet-tunnel command installed successfully!"
    else
        # If download fails, copy current script
        print_warning "Could not download latest version, installing current script..."
        
        # Get the path of the currently running script
        local current_script="${BASH_SOURCE[0]}"
        if [ -f "$current_script" ]; then
            cp "$current_script" "$INSTALLER_CMD"
            chmod +x "$INSTALLER_CMD"
            print_success "paqet-tunnel command installed from local script!"
        else
            # If running from curl pipe, save from stdin
            print_info "Saving script from current execution..."
            # Re-download or use $0
            if [ -f "$0" ]; then
                cp "$0" "$INSTALLER_CMD"
                chmod +x "$INSTALLER_CMD"
                print_success "paqet-tunnel command installed!"
            else
                print_error "Could not determine script source"
                print_info "Please run: curl -fsSL $download_url -o $INSTALLER_CMD && chmod +x $INSTALLER_CMD"
                return 1
            fi
        fi
    fi
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}         paqet-tunnel command installed!                    ${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  You can now run: ${CYAN}paqet-tunnel${NC}"
    echo ""
    echo -e "  Location: ${CYAN}$INSTALLER_CMD${NC}"
    echo ""
}

uninstall_command() {
    if [ -f "$INSTALLER_CMD" ]; then
        rm -f "$INSTALLER_CMD"
        print_success "paqet-tunnel command removed from $INSTALLER_CMD"
    else
        print_info "paqet-tunnel command is not installed"
    fi
}

is_command_installed() {
    [ -f "$INSTALLER_CMD" ]
}

#===============================================================================
# Main Menu
#===============================================================================

main() {
    check_root
    
    # Auto-sync: if paqet-tunnel command exists but is outdated, update it silently
    if is_command_installed; then
        local installed_ver=$(grep '^INSTALLER_VERSION=' "$INSTALLER_CMD" 2>/dev/null | cut -d'"' -f2)
        if [ -n "$installed_ver" ] && [ "$installed_ver" != "$INSTALLER_VERSION" ]; then
            local running_script="${BASH_SOURCE[0]}"
            if [ -f "$running_script" ]; then
                cp "$running_script" "$INSTALLER_CMD"
                chmod +x "$INSTALLER_CMD"
            fi
        fi
    fi
    
    while true; do
        print_banner
        
        # Show if command is installed
        if is_command_installed; then
            echo -e "${GREEN}[✓] paqet-tunnel command is installed. Run: ${CYAN}paqet-tunnel${NC}"
        else
            echo -e "${YELLOW}[i] Tip: Install as command with option 'i' to run: ${CYAN}paqet-tunnel${NC}"
        fi
        local core_ver
        core_ver=$(get_installed_paqet_version_text)
        local header_core_provider
        header_core_provider=$(get_current_core_provider)
        local header_profile_preset
        header_profile_preset=$(get_current_profile_preset)
        echo -e "${CYAN}[i] paqet core:${NC} ${core_ver}"
        echo -e "${CYAN}[i] core provider:${NC} $(get_core_provider_label "$header_core_provider") | ${CYAN}profile:${NC} ${header_profile_preset}"
        echo ""
        
        echo -e "${YELLOW}Select option:${NC}"
        echo ""
        echo -e "  ${GREEN}── Setup ──${NC}"
        echo -e "  ${CYAN}1)${NC} Setup Server B (Abroad - VPN server)"
        echo -e "  ${CYAN}2)${NC} Setup Server A (Iran - entry point)"
        echo ""
        echo -e "  ${GREEN}── Management ──${NC}"
        echo -e "  ${CYAN}3)${NC} Check Status"
        echo -e "  ${CYAN}4)${NC} View Configuration"
        echo -e "  ${CYAN}5)${NC} Edit Configuration"
        echo -e "  ${CYAN}6)${NC} Manage Tunnels (add/remove/restart)"
        echo -e "  ${CYAN}7)${NC} Test Connection"
        echo ""
        echo -e "  ${GREEN}── Maintenance ──${NC}"
        echo -e "  ${CYAN}8)${NC} Updates / Core / Profiles"
        echo -e "  ${CYAN}a)${NC} Automatic Reset (scheduled restart)"
        echo -e "  ${CYAN}d)${NC} Connection Protection & MTU Tuning (fix fake RST/disconnects)"
        echo -e "  ${CYAN}f)${NC} IPTables Port Forwarding (relay/NAT)"
        echo -e "  ${CYAN}u)${NC} Uninstall paqet"
        echo ""
        echo -e "  ${GREEN}── Script ──${NC}"
        if ! is_command_installed; then
            echo -e "  ${CYAN}i)${NC} Install as 'paqet-tunnel' command"
        fi
        echo -e "  ${CYAN}r)${NC} Remove paqet-tunnel command"
        echo -e "  ${CYAN}h)${NC} Donate / Support project"
        echo -e "  ${CYAN}0)${NC} Exit"
        echo ""
        read -p "Choice: " choice < /dev/tty
        
        case $choice in
            1) install_dependencies; setup_server_b ;;
            2) run_iran_optimizations; install_dependencies; setup_server_a ;;
            3) check_status ;;
            4) view_config ;;
            5) edit_config ;;
            6) manage_tunnels_menu ;;
            7) test_connection ;;
            8) updates_menu ;;
            [Bb]) update_paqet_core ;;
            [Aa]) auto_reset_menu ;;
            [Dd]) apply_connection_protection ;;
            [Ff]) iptables_port_forwarding_menu ;;
            [Uu]) uninstall ;;
            [Ii]) install_command ;;
            [Rr]) uninstall_command ;;
            [Hh]) show_donate_info ;;
            0) exit 0 ;;
            *) print_error "Invalid choice" ;;
        esac
        
        echo ""
        echo -e "${YELLOW}Press Enter to continue...${NC}"
        read < /dev/tty
    done
}

main "$@"
