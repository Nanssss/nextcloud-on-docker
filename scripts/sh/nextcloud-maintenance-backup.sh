#!/bin/bash

# Maintenance script for Nextcloud backup and upkeep, to be run at startup.

# Load environment variables
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/../setup_backup.env"

# Variables
BACKUP_DATE=$(date +%Y%m%d)
BACKUP_SNAPSHOT="$BACKUP_DIR/$BACKUP_DATE"
BACKUP_LATEST="$BACKUP_DIR/latest"
NEXTCLOUD_LOG="/var/log/nextcloud-maintenance.log"

# Route stdout & stderr to log file
exec >> $NEXTCLOUD_LOG 2>&1

# Check if the wakeup file exists
if [ ! -f "$WAKEUP_FILE_SAVE" ]; then
    echo "No RTC wakeup file, creating it in $WAKEUP_FILE_SAVE"
    /usr/local/bin/set-rtc-wakeup.sh
    exit 0
fi

# Compare the current time with the last programmed RTC alarm
PROGRAMMED=$(cat $WAKEUP_FILE_SAVE)
NOW=$(date +%s)
DIFF=$(( NOW - PROGRAMMED ))

# 10 minutes tolerance
if [ ${DIFF#-} -gt 600 ]; then
    echo "Manual boot detected (difference: ${DIFF}s), do nothing."
    exit 0
fi

echo "RTC wakeup confirmed."
echo "=== Start maintenance $(date) ==="

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"
mkdir -p "$BACKUP_SNAPSHOT"

# Wait for Docker to be ready
sleep 30

# Nextcloud maintenance mode ON
docker exec -u www-data nextcloud-nextcloud-1 php occ maintenance:mode --on

# Backup database
echo "Backup database..."
docker exec nextcloud-mariadb-1 mariadb-dump --all-databases -u root -p"$(docker exec nextcloud-mariadb-1 printenv MYSQL_ROOT_PASSWORD)" > $BACKUP_SNAPSHOT/db.sql

# Backup Nextcloud config
echo "Backup config..."
tar -czf $BACKUP_SNAPSHOT/config.tar.gz $NEXTCLOUD_DIR/nextcloud/html/config

# Backup user files
echo "Backup data..."
if [ -d "$BACKUP_LATEST/data/" ]; then
    rsync -av --delete --link-dest="$BACKUP_LATEST/data/" $NEXTCLOUD_DATA_DIR/ $BACKUP_SNAPSHOT/data/
else
    echo "No previous backup found, doing full backup..."
    rsync -av $NEXTCLOUD_DATA_DIR/ $BACKUP_SNAPSHOT/data/
fi
# Update "latest" symlink
ln -snf $BACKUP_SNAPSHOT $BACKUP_LATEST
# Keep 4 weeks of snapshots
ls -dt $BACKUP_DIR/[0-9]*/ | tail -n +5 | xargs rm -rf

# Nextcloud maintenance tasks
echo "Occ tasks..."
docker exec -u www-data nextcloud-nextcloud-1 php occ maintenance:repair
docker exec -u www-data nextcloud-nextcloud-1 php occ db:add-missing-indices

# Nextcloud maintenance mode OFF
docker exec -u www-data nextcloud-nextcloud-1 php occ maintenance:mode --off

echo "=== End of maintenance $(date) ==="

# Program next wake-up and shutdown
echo "Programming next RTC wakeup..."
/usr/local/bin/set-rtc-wakeup.sh
sleep 60
shutdown now
