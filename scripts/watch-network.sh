#!/bin/sh
# Runs a command and stops when this container has lost the network of the
# WireGuard container, for example after that container restarted on its own.
# Docker then restarts this container in the new network.

"$@" &
pid=$!
trap 'kill "$pid" 2>/dev/null; wait "$pid"; exit 0' TERM INT

while kill -0 "$pid" 2>/dev/null; do
    if [ ! -e /sys/class/net/eth0 ]; then
        echo "Lost the network of the WireGuard container, restarting."
        kill "$pid" 2>/dev/null
        exit 1
    fi
    sleep 15 &
    wait $!
done
wait "$pid"
