#!/bin/sh
# Backs up /source to the other side. Their rest-server is append-only,
# so this only adds snapshots and never removes anything.
#
# "backup.sh catch-up" runs every 15 minutes. It only backs up when a run was
# missed or failed, or the last backup is over a day old, and the other side
# is reachable. It doesn't report failures: the nightly run does that.
set -u
. /scripts/lib.sh

mode=${1:-}
stamp=/root/.cache/restic/last-backup
pending=/root/.cache/restic/backup-pending

if [ "$mode" = catch-up ]; then
    [ -e "$pending" ] || [ "$(age "$stamp")" -ge "$day" ] || exit 0
    reachable || exit 0
fi

exec 9> /tmp/backup.lock
if ! flock -n 9; then
    [ "$mode" = catch-up ] || echo "Another backup or check is running, skipped."
    exit 0
fi

if [ "$mode" != catch-up ] && ! reachable; then
    touch "$pending"
    echo "$(date '+%F %T') Can't reach the other side. Backing up as soon as it's back."
    # An offline friend is only a problem when it lasts.
    days=${NOTIFY_FAIL_AFTER_DAYS:-3}
    case $days in ''|*[!0-9]*) days=3 ;; esac
    if [ "$(age "$stamp")" -ge $((days * day)) ]; then
        echo "No backup for $days days."
        notify "${NOTIFY_FAIL_URL:-}"
    fi
    exit 1
fi

if [ "$mode" = catch-up ]; then
    echo "$(date '+%F %T') Backup started (catching up)."
else
    echo "$(date '+%F %T') Backup started."
fi
status=0
saved=0

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
        ${UPLOAD_LIMIT:+--limit-upload "$UPLOAD_LIMIT"}
    result=$?
    # 3 means a snapshot was saved, but some files couldn't be read.
    if [ "$result" -eq 0 ] || [ "$result" -eq 3 ]; then
        saved=1
        date +%s > "$stamp"
        rm -f "$pending"
    fi
    [ "$result" -eq 0 ] || status=$result
else
    echo "Backup skipped."
    status=1
fi

if [ "$status" -eq 0 ]; then
    echo "$(date '+%F %T') Backup done."
    notify "${NOTIFY_OK_URL:-}"
else
    echo "$(date '+%F %T') Backup failed (exit $status)."
    if [ "$mode" != catch-up ]; then
        [ "$saved" -eq 1 ] || touch "$pending"
        notify "${NOTIFY_FAIL_URL:-}"
    fi
fi
exit "$status"
