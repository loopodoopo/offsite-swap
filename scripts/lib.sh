# Shared by backup.sh and check.sh.

day=86400

notify() { [ -z "$1" ] || wget -q -T 30 -O /dev/null "$1" || true; }

# Seconds since the time in file $1. A missing file is created first,
# so a new setup counts from its first run.
age() {
    [ -s "$1" ] || date +%s > "$1"
    echo $(( $(date +%s) - $(cat "$1") ))
}

# Is the other side's rest-server reachable through the tunnel?
reachable() {
    target=$(sed -E 's#^rest:https?://([^@/]*@)?([^/]+)/.*#\2#' /secrets/repository 2>/dev/null) || return 1
    nc -z -w 10 "${target%:*}" "${target##*:}" 2>/dev/null
}
