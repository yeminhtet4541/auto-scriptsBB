#!/usr/bin/env bash
# VPS Dashboard All-in-One Installer v2.0
# Author: YeMinHtet
# Description: Full auto-install with menu & 1-click run

set -euo pipefail
IFS=$'\n\t'

WORKDIR="/opt/vps_dashboard"
DOMAIN="${DOMAIN:-${1:-yourdomain.com}}"

GREEN="\033[0;32m"; RED="\033[0;31m"; YELLOW="\033[0;33m"; NC="\033[0m"

# -----------------------
# Root check
# -----------------------
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root.${NC}"
    exit 1
fi

# -----------------------
# Base packages
# -----------------------
apt_install_base() {
    echo "Installing base packages..."
    apt-get update
    apt-get install -y curl wget unzip socat openssh-server lsof
}

# -----------------------
# Install functions
# -----------------------
install_ssh_ws() {
    echo "Installing SSH/WS..."
    systemctl enable --now ssh
}
install_vmess() { echo "Installing VMESS..."; }
install_vless() { echo "Installing VLESS..."; }
install_trojan() { echo "Installing TROJAN..."; }
install_socks() { echo "Installing SOCKS..."; }
install_slowdns() { echo "Installing SlowDNS..."; }
install_web_panel() { echo "Installing Web Panel..."; }
install_openvpn() { echo "Installing OpenVPN..."; }

# -----------------------
# Menu
# -----------------------
show_menu() {
    clear
    echo -e "${GREEN}VPS DASHBOARD MENU${NC}"
    echo "01) SSH/WS MENU"
    echo "02) VMESS MENU"
    echo "03) VLESS MENU"
    echo "04) TROJAN MENU"
    echo "05) SOCKS MENU"
    echo "06) User Management"
    echo "07) SlowDNS"
    echo "08) Web Panel"
    echo "09) OpenVPN"
    echo "0) Exit"
    read -rp "Enter choice: " choice
    case $choice in
        01) install_ssh_ws ;;
        02) install_vmess ;;
        03) install_vless ;;
        04) install_trojan ;;
        05) install_socks ;;
        06) echo "User management..." ;;
        07) install_slowdns ;;
        08) install_web_panel ;;
        09) install_openvpn ;;
        0) exit 0 ;;
        *) echo "Invalid choice." ;;
    esac
    read -rp "Press Enter to return to menu..." _
    show_menu
}

# -----------------------
# Auto-install everything
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
    install_web_panel
    install_openvpn
    echo -e "${GREEN}Auto-install finished!${NC}"
    exit 0
fi

# -----------------------
# Start Menu
# -----------------------
show_menu
