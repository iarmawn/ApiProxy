#!/bin/bash

# OpenAI Proxy Uninstaller

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  OpenAI Proxy Uninstaller${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Stop and disable service
stop_service() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - stop launchd service
        print_status "Stopping launchd service..."
        
        if launchctl list | grep -q com.api-proxy; then
            launchctl stop com.api-proxy
            launchctl unload ~/Library/LaunchAgents/com.api-proxy.plist
            print_status "Service stopped ✓"
        else
            print_status "Service was not running"
        fi
    else
        # Linux - stop systemd service
        print_status "Stopping and disabling service..."
        
        if systemctl is-active --quiet api-proxy; then
            systemctl stop api-proxy
            print_status "Service stopped ✓"
        else
            print_status "Service was not running"
        fi
        
        if systemctl is-enabled --quiet api-proxy; then
            systemctl disable api-proxy
            print_status "Service disabled ✓"
        else
            print_status "Service was not enabled"
        fi
    fi
}

# Remove systemd service
remove_systemd_service() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - remove launchd service
        print_status "Removing launchd service..."
        
        if [ -f ~/Library/LaunchAgents/com.api-proxy.plist ]; then
            rm ~/Library/LaunchAgents/com.api-proxy.plist
            print_status "Launchd service removed ✓"
        else
            print_status "Launchd service file not found"
        fi
    else
        # Linux - remove systemd service
        print_status "Removing systemd service..."
        
        if [ -f /etc/systemd/system/api-proxy.service ]; then
            rm /etc/systemd/system/api-proxy.service
            systemctl daemon-reload
            print_status "Systemd service removed ✓"
        else
            print_status "Systemd service file not found"
        fi
    fi
}

# Remove installation directory
remove_installation() {
    print_status "Removing installation directory..."
    
    # Get installation directory from service file if it exists
    INSTALL_DIR="/opt/openai-proxy"
    if [ -f /etc/systemd/system/openai-proxy.service ]; then
        INSTALL_DIR=$(grep "WorkingDirectory" /etc/systemd/system/openai-proxy.service | cut -d'=' -f2)
    fi
    
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
        print_status "Installation directory removed: $INSTALL_DIR ✓"
    else
        print_status "Installation directory not found: $INSTALL_DIR"
    fi
}

# Remove user
remove_user() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        # Linux only - remove service user
        print_status "Removing service user..."
        
        if id "api-proxy" &>/dev/null; then
            userdel -r api-proxy 2>/dev/null || userdel api-proxy
            print_status "Service user removed ✓"
        else
            print_status "Service user not found"
        fi
    else
        print_status "Skipping user removal on macOS"
    fi
}

# Display completion message
show_completion() {
    echo
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}  Uninstallation Complete!${NC}"
    echo -e "${GREEN}================================${NC}"
    echo
    echo -e "The API Proxy has been removed from your system."
    echo -e "If you want to reinstall, run:"
    echo -e "  ${YELLOW}curl -sSL https://raw.githubusercontent.com/iarmawn/OpenAiProxy/main/install.sh | sudo bash${NC}"
    echo
}

# Main uninstall function
main() {
    print_header
    
    # Check if running as root
    check_root
    
    # Confirm uninstallation
    echo -e "${YELLOW}This will completely remove the OpenAI Proxy from your system.${NC}"
    echo -e "This includes:"
    echo -e "  - Stopping and removing the systemd service"
    echo -e "  - Removing the installation directory"
    echo -e "  - Removing the service user"
    echo
    read -p "Are you sure you want to continue? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Uninstallation cancelled."
        exit 0
    fi
    
    # Stop service
    stop_service
    
    # Remove systemd service
    remove_systemd_service
    
    # Remove installation directory
    remove_installation
    
    # Remove user
    remove_user
    
    # Show completion message
    show_completion
}

# Run main function
main "$@" 