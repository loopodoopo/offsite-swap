#!/bin/sh
# Backs up /source to the other side. Their rest-server is append-only,
# so this only adds snapshots and never removes anything.
set -u

exec 9> /tmp/backup.lock
flock -n 9 || { echo "Another backup or check is running, skipped."; exit 0; }

notify() { [ -z "$1" ] || wget -q -T 30 -O /dev/null "$1" || true; }

echo "$(date '+%F %T') Backup started."
status=0

# A failing hook marks the run as failed, but the rest still gets backed up.
for hook in /hooks/*.sh; do
    [ -f "$hook" ] || continue
    echo "Running hook $(basename "$hook")."
    sh "$hook" || { status=1; echo "Hook $(basename "$hook") failed."; }
done

# An empty folder usually means a network share that wasn't mounted. Stop then.
empty=0
for dir in $(awk '$2 ~ "^/source/" { print $2 }' /proc/mounts); do
    if [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
        echo "$dir is empty. Is it mounted?"
        empty=1
    fi
done

if [ "$empty" -eq 0 ]; then
    restic unlock --quiet
    restic backup /source --host "$NAME" --exclude-caches \
        ${UPLOAD_LIMIT:+--limit-upload "$UPLOAD_LIMIT"} || status=$?
else
    echo "Backup skipped."
    status=1
fi

if [ "$status" -eq 0 ]; then
    echo "$(date '+%F %T') Backup done."
    notify "${NOTIFY_OK_URL:-}"
else
    echo "$(date '+%F %T') Backup failed (exit $status)."
    notify "${NOTIFY_FAIL_URL:-}"
fi
exit "$status"
