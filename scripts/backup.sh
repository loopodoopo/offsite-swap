#!/bin/sh
# Backs up /source to the other side. Their rest-server is append-only,
# so this only adds snapshots and never removes anything.
set -u

exec 9> /tmp/backup.lock
flock -n 9 || { echo "A backup is already running."; exit 0; }

notify() { [ -z "$1" ] || wget -q -T 30 -O /dev/null "$1" || true; }

echo "$(date '+%F %T') Backup started."
status=0

for hook in /hooks/*.sh; do
    [ -f "$hook" ] || continue
    echo "Running hook $(basename "$hook")."
    sh "$hook" || { status=$?; echo "Hook failed."; }
done

if [ "$status" -eq 0 ]; then
    restic unlock --quiet
    restic backup /source --host "$NAME" --exclude-caches \
        ${UPLOAD_LIMIT:+--limit-upload "$UPLOAD_LIMIT"} || status=$?
fi

if [ "$status" -eq 0 ]; then
    echo "$(date '+%F %T') Backup done."
    notify "${NOTIFY_OK_URL:-}"
else
    echo "$(date '+%F %T') Backup failed (exit $status)."
    notify "${NOTIFY_FAIL_URL:-}"
fi
exit "$status"
