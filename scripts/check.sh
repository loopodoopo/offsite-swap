#!/bin/sh
# Checks the repository at the other side. Only reads.
set -u

# restic check needs the repository to itself, so wait for a running backup.
exec 9> /tmp/backup.lock
flock -w 86400 9 || { echo "Backup still running, check skipped."; exit 0; }

echo "$(date '+%F %T') Check started."
if restic check; then
    echo "$(date '+%F %T') Check done."
else
    status=$?
    echo "$(date '+%F %T') Check failed (exit $status)."
    [ -z "${NOTIFY_FAIL_URL:-}" ] || wget -q -T 30 -O /dev/null "$NOTIFY_FAIL_URL" || true
    exit "$status"
fi
