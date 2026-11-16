#!/usr/bin/with-contenv bash
# Keeps the other side's address up to date (dynamic DNS, new IP).
# The address is not in wg0.conf, so a DNS failure never stops the tunnel.
# Runs inside the WireGuard container as a custom service.

while true; do
    sleep 30
    [[ -n "${PEER_ENDPOINT}" && -n "${PEER_PUBLIC_KEY}" ]] || continue
    wg show wg0 >/dev/null 2>&1 || continue

    last=$(wg show wg0 latest-handshakes | awk '{print $2}')
    (( $(date +%s) - ${last:-0} > 135 )) || continue

    host=${PEER_ENDPOINT%:*}
    port=${PEER_ENDPOINT##*:}
    ip=$(getent ahostsv4 "${host}" 2>/dev/null | awk 'NR == 1 {print $1}')
    if [[ -n "${ip}" ]]; then
        wg set wg0 peer "${PEER_PUBLIC_KEY}" endpoint "${ip}:${port}"
    fi
done
