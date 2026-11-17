#!/bin/sh
# Runs the nightly backup and the weekly check.
set -eu

cat > /etc/crontabs/root <<EOF
${BACKUP_SCHEDULE} /scripts/backup.sh > /proc/1/fd/1 2>&1
${CHECK_SCHEDULE} /scripts/check.sh > /proc/1/fd/1 2>&1
EOF

echo "Backup at '${BACKUP_SCHEDULE}', check at '${CHECK_SCHEDULE}' (${TZ:-UTC})."
exec crond -f -d 8
