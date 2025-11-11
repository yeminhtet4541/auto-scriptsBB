#!/usr/bin/env bash
#
# VPS Dashboard Installer v2.0
# Author: YeMinHtet (adapted)
# GitHub auto-fetch: yeminhtet4541/auto-scriptsBB
# OS: Ubuntu 22.04.5 LTS
# Usage:
#   DOMAIN=yourdomain.com sudo ./vps_dashboard_installer.sh
#
set -euo pipefail
IFS=$'\n\t'


#!/usr/bin/env bash
#
# VPS Dashboard Installer v2.0 (Fixed)
# Author: YeMinHtet (adapted)
# GitHub auto-fetch: yeminhtet4541/auto-scriptsBB
# OS: Ubuntu 22.04.5 LTS
# Usage:
#   DOMAIN=yourdomain.com sudo ./vps_dashboard_installer_fixed.sh
#

set -euo pipefail
IFS=$'\n\t'

# -----------------------
# Config
# -----------------------
GITHUB_USER="yeminhtet4541"
GITHUB_REPO="auto-scriptsBB"
WORKDIR="/opt/vps_dashboard"
LOGFILE="/var/log/vps_dashboard_installer.log"
DOMAIN="${DOMAIN:-${1:-yourdomain.com}}"
VERSION="2.0"
# Colors
GREEN="\033[0;32m"; RED="\033[0;31m"; YELLOW="\033[0;33m"; NC="\033[0m"

# Ensure run as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root.${NC}"
    exit 1
fi

# -----------------------
# Example function placeholders
# -----------------------
apt_install_base() { echo "Installing base packages..."; }
install_ssh_ws() { echo "Installing SSH/WS..."; }
install_vmess() { echo "Installing VMESS..."; }
install_vless() { echo "Installing VLESS..."; }
install_trojan() { echo "Installing TROJAN..."; }
install_socks() { echo "Installing SOCKS..."; }
install_slowdns() { echo "Installing SlowDNS..."; }
web_panel() { echo "Installing Web Panel..."; }
openvpn_menu() { echo "Installing OpenVPN..."; }

# Main menu function placeholder
main_menu() {
    while true; do
        echo "Main menu:"
        echo "[01] SSH/WS MENU"
        echo "[02] VMESS MENU"
        echo "[03] VLESS MENU"
        echo "[04] TROJAN MENU"
        echo "[05] SOCKS MENU"
        echo "[06] User Management"
        echo "[07] SlowDNS"
        echo "[08] DNS PANEL"
        echo "[09] DOMAIN PANEL"
        echo "[10] NETGUARD PANEL"
        echo "[11] VPN PORT INFO"
        echo "[12] CLEAN VPS LOGS"
        echo "[13] VPS STATUS"
        echo "[14] WEB PANEL"
        echo "[15] SCRIPT REBOOT"
        echo "[16] HTTP CUSTOM SLOWDNS"
        echo "[17] OpenVPN MENU"
        echo "[18] SCRIPT UNINSTALL"
        echo "[0] Exit"
        read -rp "Enter choice: " choice
        case $choice in
            1|01) install_ssh_ws ;;
            2|02) install_vmess ;;
            3|03) install_vless ;;
            4|04) install_trojan ;;
            5|05) install_socks ;;
            6|06) echo "User Management..." ;;
            7|07) install_slowdns ;;
            8|08) echo "DNS PANEL..." ;;
            9|09) echo "DOMAIN PANEL..." ;;
            10) echo "NETGUARD PANEL..." ;;
            11) echo "VPN PORT INFO..." ;;
            12) echo "CLEAN VPS LOGS..." ;;
            13) echo "VPS STATUS..." ;;
            14) web_panel ;;
            15) echo "SCRIPT REBOOT..." ;;
            16) echo "HTTP CUSTOM SLOWDNS..." ;;
            17) openvpn_menu ;;
            18) echo "SCRIPT UNINSTALL..." ;;
            0|00) echo "Exiting..."; exit 0 ;;
            *) echo "Invalid choice." ;;
        esac
        read -rp "Press Enter to return to menu..." _ || true
    done
}

# -----------------------
# Auto-install option
# -----------------------
if [[ "${1:-}" == "--auto-all" || "${AUTO_ALL:-}" == "1" ]]; then
    echo -e "${YELLOW}Running full auto-install...${NC}"
    apt_install_base
    install_ssh_ws
    install_vmess
    install_vless
    install_trojan
    install_socks
    install_slowdns
    web_panel
    openvpn_menu
    echo "Auto-install finished."
    exit 0
fi

# Start main menu
main_menu

# -----------------------
# Config
# -----------------------
GITHUB_USER="yeminhtet4541"
GITHUB_REPO="auto-scriptsBB"
WORKDIR="/opt/vps_dashboard"
LOGFILE="/var/log/vps_dashboard_installer.log"
DOMAIN="${DOMAIN:-${1:-yourdomain.com}}"
VERSION="2.0"

# Colors
GREEN="\033[0;32m"; RED="\033[0;31m"; YELLOW="\033[0;33m"; NC="\033[0m"

# Ensure run as root
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}This script must be run as root.${NC}"
  exit 1
fi

mkdir -p "$WORKDIR"
touch "$LOGFILE"
exec > >(tee -a "$LOGFILE") 2>&1

echo -e "${GREEN}Starting VPS Dashboard Installer v$VERSION${NC}"
echo "OS: $(lsb_release -ds || cat /etc/os-release 2>/dev/null | head -n1)"
echo "DOMAIN: $DOMAIN"
echo "Workdir: $WORKDIR"
echo

# -----------------------
# Helpers
# -----------------------
run_or_fetch_and_run() {
  local relpath="$1"
  local rawurl="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/main/${relpath}"
  echo -e "${YELLOW}Fetching ${relpath} from ${GITHUB_USER}/${GITHUB_REPO}...${NC}"
  if curl -fsSL --max-time 30 "$rawurl" -o /tmp/remote_script.sh; then
    chmod +x /tmp/remote_script.sh
    /bin/bash /tmp/remote_script.sh "$DOMAIN"
    return 0
  else
    echo -e "${RED}Remote script not found at ${rawurl} — using local/default fallback.${NC}"
    return 1
  fi
}

apt_install_base() {
  echo -e "${GREEN}Installing base packages...${NC}"
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y curl wget git unzip jq lsof net-tools iproute2 dnsutils ca-certificates gnupg2 software-properties-common ufw fail2ban
  systemctl enable --now ufw
}

# -----------------------
# Services / Menu Actions
# -----------------------
install_ssh_ws() { echo -e "${GREEN}[01] SSH/WS${NC}"; run_or_fetch_and_run "installers/ssh_ws_install.sh" || (apt_install_base; apt-get install -y openssh-server; systemctl enable --now ssh) }
install_vmess() { echo -e "${GREEN}[02] VMESS${NC}"; run_or_fetch_and_run "installers/vmess_install.sh" || apt_install_base }
install_vless() { echo -e "${GREEN}[03] VLESS${NC}"; run_or_fetch_and_run "installers/vless_install.sh" || apt_install_base }
install_trojan() { echo -e "${GREEN}[04] TROJAN${NC}"; run_or_fetch_and_run "installers/trojan_install.sh" || apt_install_base }
install_socks() { echo -e "${GREEN}[05] SOCKS${NC}"; run_or_fetch_and_run "installers/socks_install.sh" || apt_install_base }
user_management_menu() {
  echo -e "${GREEN}[06] User Management${NC}"
  PS3="Choose: "
  options=("Add user" "Delete user" "List users" "Back")
  select opt in "${options[@]}"; do
    case $REPLY in
      1) read -rp "Username: " uname; read -rp "Expire days (0=no expire): " days; useradd -m -s /bin/false "$uname"; passwd -d "$uname"; [[ "$days" -gt 0 ]] && chage -E $(date -d "+$days days" +%Y-%m-%d) "$uname"; echo "User $uname added.";;
      2) read -rp "Username to delete: " uname; userdel -r "$uname"; echo "User $uname removed.";;
      3) awk -F: '$3>=1000{print $1":"$3":"$6}' /etc/passwd;;
      4) break;;
      *) echo "Invalid";;
    esac
  done
}
install_slowdns() { echo -e "${GREEN}[07] SlowDNS${NC}"; run_or_fetch_and_run "installers/slowdns_install.sh" || apt_install_base }
dns_panel() { echo -e "${GREEN}[08] DNS PANEL${NC}"; run_or_fetch_and_run "panels/dns_panel.sh" || apt_install_base; apt-get install -y bind9 || true }
domain_panel() { echo -e "${GREEN}[09] DOMAIN PANEL${NC}"; run_or_fetch_and_run "panels/domain_panel.sh" || echo "Placeholder" }
netguard_panel() { echo -e "${GREEN}[10] NETGUARD PANEL${NC}"; ufw default deny incoming; ufw default allow outgoing; ufw allow 22/tcp; ufw allow 80; ufw allow 443; ufw --force enable; echo "Basic firewall applied." }
vpn_port_info() { echo -e "${GREEN}[11] VPN PORT INFO${NC}"; ss -tunlp | head -n 20 }
clean_vps_logs() { echo -e "${GREEN}[12] CLEAN VPS LOGS${NC}"; find /var/log -type f -name "*.log" -mtime +30 -exec truncate -s 0 {} \; || true; journalctl --vacuum-time=7d || true; echo "Logs cleaned." }
vps_status() { echo -e "${GREEN}[13] VPS STATUS${NC}"; uptime -p; free -h; df -hT /; ps aux --sort=-%mem | head -n 10 }
web_panel() { echo -e "${GREEN}[14] WEB PANEL${NC}"; run_or_fetch_and_run "panels/web_panel_install.sh" || apt_install_base; apt-get install -y nginx php-fpm || true; systemctl enable --now nginx }
script_reboot() { read -rp "Reboot server now? (y/N): " confirm; [[ "$confirm" =~ ^[Yy] ]] && reboot || echo "Cancelled." }
http_custom_slowdns() { echo -e "${GREEN}[16] HTTP custom SlowDNS${NC}"; run_or_fetch_and_run "tools/http_custom_slowdns.sh" || echo "Placeholder" }
script_uninstall() { read -rp "Uninstall dashboard? (y/N): " confirm; [[ "$confirm" =~ ^[Yy] ]] && (rm -rf "$WORKDIR"; ufw --force disable; echo "Uninstalled.") || echo "Cancelled." }

# -----------------------
# All Ports Detection + UFW allow
# -----------------------
all_ports_menu() {
  echo -e "${GREEN}[17] All Server Ports${NC}"
  ss -tunlp | awk 'NR>1{print $1,$5,$6}' | column -t
  read -rp "Allow all detected ports in UFW? (y/N): " allow
  if [[ "$allow" =~ ^[Yy] ]]; then
    ports=$(ss -tunlp | awk 'NR>1{split($5,a,":"); print a[length(a)]}' | sort -u)
    for p in $ports; do ufw allow "$p"; done
    echo "All detected ports allowed in UFW."
  fi
}

# -----------------------
# OPENVPN Menu
# -----------------------
openvpn_menu() {
  echo -e "${GREEN}[18] OPENVPN MENU${NC}"
  PS3="Choose: "
  options=("Install OpenVPN" "Generate client config" "Start OpenVPN" "Stop OpenVPN" "Restart OpenVPN" "Status" "Back")
  select opt in "${options[@]}"; do
    case $REPLY in
      1) run_or_fetch_and_run "installers/openvpn_install.sh" || (apt_install_base; apt-get install -y openvpn easy-rsa) ;;
      2) run_or_fetch_and_run "tools/openvpn_gen_client.sh" || echo "Generate client config placeholder." ;;
      3) systemctl start openvpn@server || echo "Start OpenVPN placeholder." ;;
      4) systemctl stop openvpn@server || echo "Stop OpenVPN placeholder." ;;
      5) systemctl restart openvpn@server || echo "Restart OpenVPN placeholder." ;;
      6) systemctl status openvpn@server || echo "Status placeholder." ;;
      7) break ;;
      *) echo "Invalid";;
    esac
  done
}

exit_script() { echo -e "${GREEN}Bye!${NC}"; exit 0 }

# -----------------------
# Main Menu
# -----------------------
main_menu() {
  while true; do
    cat <<-MENU

    ================= VPS DASHBOARD =================
    OS         : Ubuntu 22.04.5 LTS
    UPTIME     : $(uptime -p)
    IPv4       : $(hostname -I | awk '{print $1}')
    DOMAIN     : $DOMAIN

    [01] SSH/WS MENU
    [02] VMESS MENU
    [03] VLESS MENU
    [04] TROJAN MENU
    [05] SOCKS MENU
    [06] User management
    [07] SlowDNS
    [08] DNS PANEL
    [09] DOMAIN PANEL
    [10] NETGUARD PANEL
    [11] VPN PORT INFO
    [12] CLEAN VPS LOGS
    [13] VPS STATUS
    [14] WEB PANEL
    [15] SCRIPT REBOOT
    [16] http custom slowdns
    [16] SCRIPT Uninstall
    [17] All Server Ports + UFW allow
    [18] OPENVPN MENU
    [00] EXIT

    VERSION      : $VERSION
    SCRIPT BY    :  $GITHUB_USER
MENU
    read -rp "Choose an option: " choice
    case "$choice" in
      1|01) install_ssh_ws ;;
      2|02) install_vmess ;;
      3|03) install_vless ;;
      4|04) install_trojan ;;
      5|05) install_socks ;;
      6|06) user_management_menu ;;
      7|07) install_slowdns ;;
      8|08) dns_panel ;;
      9|09) domain_panel ;;
      10) netguard_panel ;;
      11) vpn_port_info ;;
      12) clean_vps_logs ;;
      13) vps_status ;;
      14) web_panel ;;
      15) script_reboot ;;
      16) http_custom_slowdns ;;
      16|uninstall) script_uninstall ;;
      17) all_ports_menu ;;
      18) openvpn_menu ;;
      0|00) exit_script ;;
      *) echo "Invalid choice." ;;
    esac
    read -rp "Press Enter to return to menu..." _ || true
  done
}

# -----------------------
# Auto-install option
# -----------------------
if [[ "${1:-}" == "--auto-all" || "${AUTO_ALL:-}" == "1" ]]; then
  echo -e "${YELLOW}Running full auto-install...${NC}"
  apt_install_base
  install_ssh_ws
  install_vmess
  install_vless
  install_trojan
  install_socks
  install_slowdns
  web_panel
  openvpn_menu
  echo "Auto-install finished."
  exit 0
fi

# Start main menu
main_menu
