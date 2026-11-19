#!/bin/sh
# Runs the nightly backup and the weekly check, and catches up on missed ones.
set -eu

cat > /etc/crontabs/root <<CRON
${BACKUP_SCHEDULE} /scripts/backup.sh > /proc/1/fd/1 2>&1
${CHECK_SCHEDULE} /scripts/check.sh > /proc/1/fd/1 2>&1
*/15 * * * * /scripts/backup.sh catch-up > /proc/1/fd/1 2>&1; /scripts/check.sh catch-up > /proc/1/fd/1 2>&1
CRON

echo "Backup at '${BACKUP_SCHEDULE}', check at '${CHECK_SCHEDULE}' (${TZ:-UTC}). Missed ones are caught up."
exec /scripts/watch-network.sh crond -f -d 8
