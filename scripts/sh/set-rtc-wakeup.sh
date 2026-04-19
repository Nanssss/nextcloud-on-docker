#!/bin/bash

# Script to set RTC wakeup for next maintenance task on next friday at 3am.

# Load environment variables
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/../setup_backup.env"

# Next wakeup time
NEXT=$(date -d "next $WAKEUP_DAY $WAKEUP_TIME" +%s)

# Program RTC
sudo rtcwake -m no -t $NEXT >> $RTC_LOG 2>&1

# Save the programmed wakeup time for verification at startup
echo $NEXT > $WAKEUP_FILE_SAVE

echo "Next wake-up: $(date -d @$NEXT)" >> $RTC_LOG
