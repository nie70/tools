#!/bin/bash

# Log file
LOGFILE="/var/log/update_script.log"
exec > >(tee -a $LOGFILE) 2>&1

# Backup directory
BACKUP_DIR="/backup_location"

# Function to ask for user confirmation
confirm_action() {
    read -p "$1 (y/n)? " choice
    case "$choice" in
        y|Y ) true;;
        n|N ) exit;;
        * ) echo "Invalid choice. Exiting."; exit;;
    esac
}

# Function to run commands and check for errors
run_command() {
    "$@"
    if [ $? -ne 0 ]; then
        echo "Command failed: $*"
        exit 1
    fi
}

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
fi

# Check for internet connectivity
if ! ping -c 1 8.8.8.8 &> /dev/null; then
    echo "No internet connection. Exiting."
    exit 1
fi

# Create backup directory if it doesn't exist
if [ ! -d "$BACKUP_DIR" ]; then
    echo "Backup directory $BACKUP_DIR does not exist. Creating it..."
    mkdir -p "$BACKUP_DIR"
    if [ $? -ne 0 ]; then
        echo "Failed to create backup directory. Exiting."
        exit 1
    fi
fi

# Check for pending reboots
if [ -f /var/run/reboot-required ]; then
    echo "A reboot is required. Please reboot the system before proceeding with updates."
    exit 1
fi

# Capture running services before update
echo "Capturing running services before update..."
run_command systemctl list-units --type=service --state=running > "$BACKUP_DIR/services_before_update.txt"

# Backup your system
confirm_action "Have you backed up your system?"
echo "Proceeding with the update process..."

# Check system health
echo "Checking disk space..."
df -h

echo "Checking for broken packages..."
run_command sudo dpkg --configure -a
run_command sudo apt-get check

# Update the package list
confirm_action "Do you want to update the package list?"
run_command sudo apt update

# Review available updates
echo "Reviewing available updates..."
run_command sudo apt list --upgradable

# Apply the updates
confirm_action "Do you want to apply the updates?"
run_command sudo apt upgrade

# Capture running services after update
echo "Capturing running services after update..."
run_command systemctl list-units --type=service --state=running > "$BACKUP_DIR/services_after_update.txt"

# Compare services before and after
echo "Comparing running services before and after the update..."
diff "$BACKUP_DIR/services_before_update.txt" "$BACKUP_DIR/services_after_update.txt"

# Reboot if necessary
confirm_action "Do you want to reboot the system now (if necessary)?"
run_command sudo reboot
