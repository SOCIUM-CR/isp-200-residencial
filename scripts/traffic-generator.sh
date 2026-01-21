#!/bin/sh
# =============================================================================
# Traffic Generator - Simulates ISP user traffic
# =============================================================================

echo "[TRAFFIC-GEN] Starting traffic generator..."
echo "[TRAFFIC-GEN] Targets: upstream(192.168.200.1), edge(192.168.200.2), all CPEs"

# Wait for network to stabilize
sleep 10

# Infinite loop generating traffic
while true; do
    echo "[TRAFFIC-GEN] === Round started at $(date) ==="

    # Ping upstream (simulates DNS/connectivity checks)
    ping -c 5 -i 0.2 192.168.200.1 > /dev/null 2>&1 &

    # Ping edge router
    ping -c 5 -i 0.2 192.168.200.2 > /dev/null 2>&1 &

    # Ping all CPEs (simulates broadcast/multicast traffic)
    for cpe in 192.168.201.10 192.168.201.20 192.168.201.30 192.168.201.40 192.168.201.50 192.168.201.60; do
        ping -c 3 -i 0.1 $cpe > /dev/null 2>&1 &
    done

    # HTTP traffic to upstream (simulates web browsing)
    for i in 1 2 3 4 5; do
        curl -s -o /dev/null --connect-timeout 2 http://192.168.200.1/ 2>/dev/null &
        curl -s -o /dev/null --connect-timeout 2 http://192.168.200.2/ 2>/dev/null &
    done

    # Large data transfer simulation (iperf-like using dd + netcat if available)
    # This creates actual bandwidth usage
    dd if=/dev/zero bs=1M count=5 2>/dev/null | nc -w 2 192.168.200.1 12345 2>/dev/null &
    dd if=/dev/zero bs=1M count=5 2>/dev/null | nc -w 2 192.168.200.2 12345 2>/dev/null &

    # Traceroute simulation
    traceroute -n -m 5 192.168.200.1 > /dev/null 2>&1 &

    # Wait before next round
    wait
    sleep 2

done
