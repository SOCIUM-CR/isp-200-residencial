#!/bin/sh
# =============================================================================
# QoS Monitor - Real-time traffic shaping statistics
# =============================================================================
# Muestra estadísticas de QoS en tiempo real
# Uso: ./qos-monitor.sh [interface] [interval]
# =============================================================================

IFACE=${1:-eth0}
INTERVAL=${2:-2}

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    clear
    echo "${BLUE}=========================================="
    echo "  QoS Monitor - ISP-200 Traffic Shaper"
    echo "==========================================${NC}"
    echo ""
    echo "Interface: ${GREEN}$IFACE${NC}"
    echo "Refresh: every ${INTERVAL}s"
    echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
}

print_class_stats() {
    echo "${YELLOW}--- Traffic Classes ---${NC}"
    echo ""
    printf "%-10s %-15s %-12s %-12s %-10s\n" "CLASS" "RATE" "SENT" "DROPPED" "OVERLIMITS"
    echo "------------------------------------------------------------"

    tc -s class show dev "$IFACE" 2>/dev/null | awk '
    /class htb/ {
        classid = $3
        rate = ""
        sent = ""
        dropped = ""
        overlimits = ""
    }
    /rate/ && /ceil/ {
        rate = $2
    }
    /Sent/ {
        sent = $2 " bytes"
        for(i=1; i<=NF; i++) {
            if($i == "dropped") dropped = $(i+1)
            if($i == "overlimits") overlimits = $(i+1)
        }
        printf "%-10s %-15s %-12s %-12s %-10s\n", classid, rate, sent, dropped, overlimits
    }
    '
    echo ""
}

print_plan_mapping() {
    echo "${YELLOW}--- Subscriber Plans ---${NC}"
    echo ""
    printf "%-18s %-12s %-10s\n" "SUBSCRIBER" "PLAN" "SPEED"
    echo "----------------------------------------"
    echo "192.168.201.10     Básico       10 Mbps"
    echo "192.168.201.20     Básico       10 Mbps"
    echo "192.168.201.30     Estándar     25 Mbps"
    echo "192.168.201.40     Estándar     25 Mbps"
    echo "192.168.201.50     Premium      50 Mbps"
    echo "192.168.201.60     Ultra       100 Mbps"
    echo ""
}

print_qdisc_stats() {
    echo "${YELLOW}--- Queue Disciplines ---${NC}"
    echo ""
    tc -s qdisc show dev "$IFACE" 2>/dev/null | head -30
    echo ""
}

print_bandwidth_usage() {
    echo "${YELLOW}--- Bandwidth Usage (last ${INTERVAL}s) ---${NC}"
    echo ""

    # Obtener bytes antes
    RX_BEFORE=$(cat /sys/class/net/$IFACE/statistics/rx_bytes 2>/dev/null || echo 0)
    TX_BEFORE=$(cat /sys/class/net/$IFACE/statistics/tx_bytes 2>/dev/null || echo 0)

    sleep 1

    # Obtener bytes después
    RX_AFTER=$(cat /sys/class/net/$IFACE/statistics/rx_bytes 2>/dev/null || echo 0)
    TX_AFTER=$(cat /sys/class/net/$IFACE/statistics/tx_bytes 2>/dev/null || echo 0)

    # Calcular diferencia
    RX_DIFF=$((RX_AFTER - RX_BEFORE))
    TX_DIFF=$((TX_AFTER - TX_BEFORE))

    # Convertir a Mbps
    RX_MBPS=$(echo "scale=2; $RX_DIFF * 8 / 1000000" | bc 2>/dev/null || echo "N/A")
    TX_MBPS=$(echo "scale=2; $TX_DIFF * 8 / 1000000" | bc 2>/dev/null || echo "N/A")

    echo "  Download (RX): ${GREEN}${RX_MBPS} Mbps${NC}"
    echo "  Upload (TX):   ${GREEN}${TX_MBPS} Mbps${NC}"
    echo ""
}

# =============================================================================
# Main loop
# =============================================================================

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Usage: $0 [interface] [interval]"
    echo ""
    echo "  interface: Network interface to monitor (default: eth0)"
    echo "  interval:  Refresh interval in seconds (default: 2)"
    echo ""
    echo "Examples:"
    echo "  $0              # Monitor eth0, refresh every 2s"
    echo "  $0 eth1 5       # Monitor eth1, refresh every 5s"
    exit 0
fi

# Verificar que la interfaz existe
if ! ip link show "$IFACE" > /dev/null 2>&1; then
    echo "${RED}[ERROR] Interface $IFACE not found${NC}"
    echo ""
    echo "Available interfaces:"
    ip link show | grep -E "^[0-9]+" | awk '{print "  " $2}' | tr -d ':'
    exit 1
fi

echo "Starting QoS monitor for $IFACE..."
echo "Press Ctrl+C to stop"
sleep 2

while true; do
    print_header
    print_plan_mapping
    print_class_stats
    print_qdisc_stats
    echo "${BLUE}Press Ctrl+C to stop${NC}"
    sleep "$INTERVAL"
done
