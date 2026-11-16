#!/bin/sh
# Checks the repository at the other side. Only reads.
set -u

echo "$(date '+%F %T') Check started."
if restic check; then
    echo "$(date '+%F %T') Check done."
else
    status=$?
    echo "$(date '+%F %T') Check failed (exit $status)."
    [ -z "${NOTIFY_FAIL_URL:-}" ] || wget -q -T 30 -O /dev/null "$NOTIFY_FAIL_URL" || true
    exit "$status"
fi
