#!/bin/bash

# Setup script for server tools

# Load environment variables
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/setup_backup.env"

# Ask user to confirm they updated the nginx configuration
read -p "Did you correctly fill your .env file? (Yes/no) " answer
if [ "$answer" != "Yes" ]; then
    echo "Please update your .env file and run the script again."
    exit 1
fi

# Create symbolic links in /usr/local/bin
echo "Creating symbolic links for scripts..."
sudo ln -s $SCRIPT_DIR/sh/nextcloud-maintenance-backup.sh /usr/local/bin/
sudo ln -s $SCRIPT_DIR/sh/set-rtc-wakeup.sh /usr/local/bin/

# Create and enable services
echo "Creating and enabling services..."
sudo ln -s $SCRIPT_DIR/res/nextcloud-maintenance.service /etc/systemd/system
sudo systemctl enable nextcloud-maintenance.service

echo "Setup completed :)"
