#!/bin/sh
# =============================================================================
# tc-exporter - Prometheus Exporter for tc/QoS Statistics
# =============================================================================
# Expone métricas de traffic control en formato Prometheus
# Puerto: 9100
# =============================================================================

PORT=${1:-9100}
IFACE=${2:-eth0}

# Instalar dependencias
apk add --no-cache busybox-extras iproute2 >/dev/null 2>&1

echo "[tc-exporter] Starting on port $PORT, monitoring $IFACE"

# Función para generar métricas
generate_metrics() {
    cat <<EOF
# HELP tc_qdisc_bytes_total Total bytes sent through qdisc
# TYPE tc_qdisc_bytes_total counter
# HELP tc_qdisc_packets_total Total packets sent through qdisc
# TYPE tc_qdisc_packets_total counter
# HELP tc_qdisc_drops_total Total packets dropped
# TYPE tc_qdisc_drops_total counter
# HELP tc_qdisc_overlimits_total Total overlimit events
# TYPE tc_qdisc_overlimits_total counter
# HELP tc_qdisc_requeues_total Total requeue events
# TYPE tc_qdisc_requeues_total counter
# HELP tc_class_rate_bytes Configured rate in bytes/sec
# TYPE tc_class_rate_bytes gauge
# HELP tc_class_ceil_bytes Configured ceil in bytes/sec
# TYPE tc_class_ceil_bytes gauge
EOF

    # Parsear estadísticas de qdisc
    tc -s qdisc show dev $IFACE 2>/dev/null | awk -v iface="$IFACE" '
    /^qdisc/ {
        qdisc_type=$2
        handle=$3
        gsub(/:/, "", handle)
    }
    /Sent/ {
        bytes=$2
        packets=$4
        gsub(/[^0-9]/, "", packets)
        # Extract dropped, overlimits, requeues
        dropped=0; overlimits=0; requeues=0
        for(i=1; i<=NF; i++) {
            if($i == "dropped") { dropped=$(i+1); gsub(/,/, "", dropped) }
            if($i == "overlimits") { overlimits=$(i+1); gsub(/,/, "", overlimits) }
            if($i == "requeues") { requeues=$(i+1); gsub(/\)/, "", requeues) }
        }
        printf "tc_qdisc_bytes_total{interface=\"%s\",qdisc=\"%s\",handle=\"%s\"} %s\n", iface, qdisc_type, handle, bytes
        printf "tc_qdisc_packets_total{interface=\"%s\",qdisc=\"%s\",handle=\"%s\"} %s\n", iface, qdisc_type, handle, packets
        printf "tc_qdisc_drops_total{interface=\"%s\",qdisc=\"%s\",handle=\"%s\"} %s\n", iface, qdisc_type, handle, dropped
        printf "tc_qdisc_overlimits_total{interface=\"%s\",qdisc=\"%s\",handle=\"%s\"} %s\n", iface, qdisc_type, handle, overlimits
        printf "tc_qdisc_requeues_total{interface=\"%s\",qdisc=\"%s\",handle=\"%s\"} %s\n", iface, qdisc_type, handle, requeues
    }
    '

    # Parsear estadísticas de clases HTB
    tc -s class show dev $IFACE 2>/dev/null | awk -v iface="$IFACE" '
    /^class htb/ {
        classid=$3
        # Parse rate and ceil
        rate=0; ceil=0
        for(i=1; i<=NF; i++) {
            if($i == "rate") {
                rate=$(i+1)
                # Convert to bytes: Mbit->bytes, Kbit->bytes, bit->bytes
                if(rate ~ /Gbit/) { gsub(/Gbit/, "", rate); rate=rate*125000000 }
                else if(rate ~ /Mbit/) { gsub(/Mbit/, "", rate); rate=rate*125000 }
                else if(rate ~ /Kbit/) { gsub(/Kbit/, "", rate); rate=rate*125 }
                else if(rate ~ /bit/) { gsub(/bit/, "", rate); rate=rate/8 }
            }
            if($i == "ceil") {
                ceil=$(i+1)
                if(ceil ~ /Gbit/) { gsub(/Gbit/, "", ceil); ceil=ceil*125000000 }
                else if(ceil ~ /Mbit/) { gsub(/Mbit/, "", ceil); ceil=ceil*125000 }
                else if(ceil ~ /Kbit/) { gsub(/Kbit/, "", ceil); ceil=ceil*125 }
                else if(ceil ~ /bit/) { gsub(/bit/, "", ceil); ceil=ceil/8 }
            }
        }
        current_class=classid
        current_rate=rate
        current_ceil=ceil
    }
    /Sent/ && current_class {
        bytes=$2
        packets=$4
        gsub(/[^0-9]/, "", packets)
        dropped=0; overlimits=0; requeues=0
        for(i=1; i<=NF; i++) {
            if($i == "dropped") { dropped=$(i+1); gsub(/,/, "", dropped) }
            if($i == "overlimits") { overlimits=$(i+1); gsub(/,/, "", overlimits) }
            if($i == "requeues") { requeues=$(i+1); gsub(/\)/, "", requeues) }
        }
        printf "tc_class_bytes_total{interface=\"%s\",classid=\"%s\"} %s\n", iface, current_class, bytes
        printf "tc_class_packets_total{interface=\"%s\",classid=\"%s\"} %s\n", iface, current_class, packets
        printf "tc_class_drops_total{interface=\"%s\",classid=\"%s\"} %s\n", iface, current_class, dropped
        printf "tc_class_overlimits_total{interface=\"%s\",classid=\"%s\"} %s\n", iface, current_class, overlimits
        printf "tc_class_rate_bytes{interface=\"%s\",classid=\"%s\"} %s\n", iface, current_class, current_rate
        printf "tc_class_ceil_bytes{interface=\"%s\",classid=\"%s\"} %s\n", iface, current_class, current_ceil
    }
    '
}

# Servidor HTTP simple con netcat
while true; do
    METRICS=$(generate_metrics)
    RESPONSE="HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: ${#METRICS}\r\nConnection: close\r\n\r\n${METRICS}"
    echo -e "$RESPONSE" | nc -l -p $PORT -q 1 2>/dev/null || echo -e "$RESPONSE" | nc -l -p $PORT 2>/dev/null
done
