#!/bin/bash

# Strict mode
set -euo pipefail
IFS=$'\n\t'

# Script variables
SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
LOG_FILE="/var/log/system_config.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Define color codes
readonly GREEN="\033[1;32m"
readonly YELLOW="\033[1;33m"
readonly RED="\033[1;31m"
readonly RESET="\033[0m"

# Configuration variables
readonly ROOT_PASSWORD="XXZZea"
readonly SSH_PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIN4uOC31nqauqW85lC1B4jnO4HGmGxrJC+4r7vMBzb2"
readonly PACKAGES="sudo curl wget vim htop neofetch systemd-timesyncd"

# Parse command line arguments
HOSTNAME=""
if [[ $# -gt 0 ]]; then
    if [[ "$1" == "-hostname" ]]; then
        [[ $# -lt 2 ]] && { echo "Error: -hostname requires an argument"; exit 1; }
        HOSTNAME="$2"
    else
        HOSTNAME="$1"
    fi
fi

# Logging functions
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') [${1}] ${2}" | tee -a "$LOG_FILE"
}

success_message() { log "SUCCESS" "${GREEN}$1${RESET}"; }
warning_message() { log "WARNING" "${YELLOW}$1${RESET}"; }
error_message() { log "ERROR" "${RED}$1${RESET}"; }

# Configure APT
configure_apt() {
    echo "Configuring APT..."
    local apt_config="/etc/apt/apt.conf.d/99norecommends"
    cat > "$apt_config" <<EOF
APT::Install-Recommends "false";
APT::Install-Suggests "false";
APT::Acquire::Retries "3";
EOF
    success_message "APT configured successfully"
}

# Configure SSH
configure_ssh() {
    echo "Configuring SSH..."
    local sshd_config="/etc/ssh/sshd_config"
    
    # Set root password
    echo "root:${ROOT_PASSWORD}" | chpasswd
    
    # Configure SSH
    sed -i '/^#PermitRootLogin/c\PermitRootLogin yes' "$sshd_config"
    sed -i '/^#PasswordAuthentication/c\PasswordAuthentication yes' "$sshd_config"
    
    systemctl restart sshd || warning_message "Failed to restart SSH service"
    success_message "SSH configured successfully"
}

# Setup SSH keys
setup_ssh_keys() {
    echo "Setting up SSH keys..."
    mkdir -p /root/.ssh
    echo "$SSH_PUBLIC_KEY" > /root/.ssh/authorized_keys
    chmod 700 /root/.ssh
    chmod 600 /root/.ssh/authorized_keys
    success_message "SSH keys configured successfully"
}

# Install packages
install_packages() {
    echo "Installing packages..."
    apt-get update -qq || warning_message "Failed to update package list"
    DEBIAN_FRONTEND=noninteractive apt-get install -y $PACKAGES --no-install-recommends >/dev/null 2>&1 || true
    success_message "Package installation completed"
}

# Configure time settings
configure_time() {
    echo "Configuring time settings..."
    systemctl enable systemd-timesyncd >/dev/null 2>&1 || true
    systemctl start systemd-timesyncd >/dev/null 2>&1 || true
    timedatectl set-ntp true >/dev/null 2>&1 || true
    timedatectl set-timezone Asia/Shanghai >/dev/null 2>&1 || true
    success_message "Time configuration completed"
}

# Configure network settings
configure_network() {
    echo "Configuring network settings..."
    
    # Set hostname only if provided
    if [[ -n "$HOSTNAME" ]]; then
        echo "Setting hostname to: $HOSTNAME"
        hostnamectl set-hostname "$HOSTNAME" >/dev/null 2>&1 || true
        
        # Configure hosts file
        cat > /etc/hosts <<EOF
127.0.0.1   localhost $HOSTNAME
::1         localhost $HOSTNAME
EOF
    else
        echo "Hostname not provided, skipping hostname configuration"
    fi
    
    # Configure DNS
    cat > /etc/resolv.conf <<EOF
options timeout:2 attempts:3 rotate
nameserver 1.1.1.1
nameserver 1.0.0.1
nameserver 2606:4700:4700::1111
nameserver 2606:4700:4700::1001
EOF
    
    success_message "Network configuration completed"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error_message "This script must be run as root"
    exit 1
fi

# Main execution
{
    success_message "Starting configuration script..."
    [[ -n "$HOSTNAME" ]] && echo -e "${GREEN}Using hostname: $HOSTNAME${RESET}"
    
    configure_apt
    configure_ssh
    setup_ssh_keys
    install_packages
    configure_time
    configure_network
    
    success_message "Configuration completed successfully!"
    echo -e "\n${GREEN}All tasks completed! System has been configured successfully.${RESET}\n"
} || {
    error_message "Script failed! Check the log file at $LOG_FILE for details."
    exit 1
}

# Display final status
echo -e "\n${GREEN}Summary of configurations:${RESET}"
echo -e "1. APT configuration: ${GREEN}✓${RESET}"
echo -e "2. SSH configuration: ${GREEN}✓${RESET}"
echo -e "3. SSH keys: ${GREEN}✓${RESET}"
echo -e "4. Package installation: ${GREEN}✓${RESET}"
echo -e "5. Time settings: ${GREEN}✓${RESET}"
echo -e "6. Network settings: ${GREEN}✓${RESET}"
[[ -n "$HOSTNAME" ]] && echo -e "Current hostname: ${GREEN}$HOSTNAME${RESET}"
