#!/bin/sh
# Checks the repository at the other side. Only reads.
#
# "check.sh catch-up" runs every 15 minutes. It only checks when the last
# check is over a week old and the other side is reachable.
set -u
. /scripts/lib.sh

mode=${1:-}
stamp=/root/.cache/restic/last-check

if [ "$mode" = catch-up ]; then
    [ "$(age "$stamp")" -ge $((7 * day)) ] || exit 0
    reachable || exit 0
    # Don't wait for a running backup, just try again later.
    exec 9> /tmp/backup.lock
    flock -n 9 || exit 0
else
    if ! reachable; then
        echo "$(date '+%F %T') Can't reach the other side. Checking as soon as it's back."
        exit 1
    fi
    # restic check needs the repository to itself, so wait for a running backup.
    exec 9> /tmp/backup.lock
    timeout 86400 flock 9 || { echo "Backup still running after a day, check skipped."; exit 0; }
fi

echo "$(date '+%F %T') Check started."
# A backup that was cut off (a server went down) can leave a stale lock.
restic unlock --quiet
restic check
status=$?
date +%s > "$stamp"
if [ "$status" -eq 0 ]; then
    echo "$(date '+%F %T') Check done."
else
    echo "$(date '+%F %T') Check failed (exit $status)."
    notify "${NOTIFY_FAIL_URL:-}"
fi
exit "$status"
