#!/bin/sh
# =============================================================================
# QoS Shaper Setup Script - tc + CAKE Implementation
# =============================================================================
# Implementa traffic shaping similar a LibreQoS usando tc + CAKE
# Compatible con Docker/macOS (no requiere XDP/eBPF)
# =============================================================================

set -e

echo "=========================================="
echo "QoS Shaper - tc + CAKE Implementation"
echo "=========================================="

# Verificar que tenemos las herramientas necesarias
if ! command -v tc > /dev/null 2>&1; then
    echo "[ERROR] tc not found. Installing iproute2..."
    apk add --no-cache iproute2 iproute2-tc
fi

# Cargar modulo CAKE si está disponible (puede fallar en Docker)
modprobe sch_cake 2>/dev/null || echo "[WARN] CAKE module not loadable (expected in Docker)"

# Detectar interfaz principal
IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
if [ -z "$IFACE" ]; then
    IFACE="eth0"
fi

echo "[INFO] Interface detected: $IFACE"

# =============================================================================
# Configuración de Planes de Servicio (Bandwidth Tiers)
# =============================================================================
# Estos valores simulan planes típicos de ISP residencial

# Plan Básico: 10 Mbps down / 2 Mbps up
PLAN_BASIC_DOWN="10mbit"
PLAN_BASIC_UP="2mbit"

# Plan Estándar: 25 Mbps down / 5 Mbps up
PLAN_STANDARD_DOWN="25mbit"
PLAN_STANDARD_UP="5mbit"

# Plan Premium: 50 Mbps down / 10 Mbps up
PLAN_PREMIUM_DOWN="50mbit"
PLAN_PREMIUM_UP="10mbit"

# Plan Ultra: 100 Mbps down / 20 Mbps up
PLAN_ULTRA_DOWN="100mbit"
PLAN_ULTRA_UP="20mbit"

# Capacidad total del enlace (simula uplink del ISP)
TOTAL_BANDWIDTH="1gbit"

# =============================================================================
# Función: Aplicar QoS con CAKE
# =============================================================================
apply_cake_qos() {
    local iface=$1
    local bandwidth=$2
    local direction=$3  # "ingress" o "egress"

    echo "[INFO] Applying CAKE on $iface ($direction) - $bandwidth"

    # Limpiar qdisc existente
    tc qdisc del dev "$iface" root 2>/dev/null || true
    tc qdisc del dev "$iface" ingress 2>/dev/null || true

    if [ "$direction" = "egress" ]; then
        # CAKE para tráfico de salida (download hacia clientes)
        # bandwidth: límite de velocidad
        # besteffort: sin clasificación DSCP
        # flowblind: trata todos los flujos igual
        # nat: maneja NAT correctamente
        # wash: limpia marcas DSCP entrantes
        tc qdisc add dev "$iface" root cake \
            bandwidth "$bandwidth" \
            besteffort \
            flowblind \
            nat \
            wash \
            ack-filter \
            split-gso \
            rtt 20ms \
            2>/dev/null || {
                # Fallback a fq_codel si CAKE no está disponible
                echo "[WARN] CAKE not available, using fq_codel fallback"
                tc qdisc add dev "$iface" root fq_codel \
                    limit 10240 \
                    target 5ms \
                    interval 100ms \
                    quantum 1514 \
                    ecn
            }
    fi
}

# =============================================================================
# Función: Aplicar HTB + CAKE para múltiples clases
# =============================================================================
apply_htb_cake() {
    local iface=$1

    echo "[INFO] Setting up HTB + CAKE hierarchy on $iface"

    # Limpiar configuración existente
    tc qdisc del dev "$iface" root 2>/dev/null || true

    # Crear qdisc raíz HTB
    tc qdisc add dev "$iface" root handle 1: htb default 40

    # Clase raíz con bandwidth total
    tc class add dev "$iface" parent 1: classid 1:1 htb \
        rate "$TOTAL_BANDWIDTH" \
        ceil "$TOTAL_BANDWIDTH" \
        burst 15k

    # Clase para tráfico prioritario (VoIP, gaming)
    tc class add dev "$iface" parent 1:1 classid 1:10 htb \
        rate 100mbit \
        ceil 200mbit \
        burst 15k \
        prio 1

    # Clase Plan Ultra (100M)
    tc class add dev "$iface" parent 1:1 classid 1:20 htb \
        rate "$PLAN_ULTRA_DOWN" \
        ceil "$PLAN_ULTRA_DOWN" \
        burst 15k \
        prio 2

    # Clase Plan Premium (50M)
    tc class add dev "$iface" parent 1:1 classid 1:30 htb \
        rate "$PLAN_PREMIUM_DOWN" \
        ceil "$PLAN_PREMIUM_DOWN" \
        burst 15k \
        prio 3

    # Clase Plan Estándar (25M) - Default
    tc class add dev "$iface" parent 1:1 classid 1:40 htb \
        rate "$PLAN_STANDARD_DOWN" \
        ceil "$PLAN_STANDARD_DOWN" \
        burst 15k \
        prio 4

    # Clase Plan Básico (10M)
    tc class add dev "$iface" parent 1:1 classid 1:50 htb \
        rate "$PLAN_BASIC_DOWN" \
        ceil "$PLAN_BASIC_DOWN" \
        burst 15k \
        prio 5

    # Agregar CAKE o fq_codel a cada clase para AQM
    for classid in 10 20 30 40 50; do
        tc qdisc add dev "$iface" parent 1:$classid handle $classid: fq_codel \
            limit 10240 \
            target 5ms \
            interval 100ms \
            quantum 1514 \
            ecn \
            2>/dev/null || true
    done

    echo "[INFO] HTB hierarchy created with 5 service classes"
}

# =============================================================================
# Función: Crear filtros para clasificar tráfico por IP
# =============================================================================
create_ip_filters() {
    local iface=$1

    echo "[INFO] Creating IP-based traffic filters"

    # CPE-1 y CPE-2 (192.168.201.10-29) -> Plan Básico (10M)
    tc filter add dev "$iface" parent 1: protocol ip prio 1 u32 \
        match ip dst 192.168.201.10/32 flowid 1:50 2>/dev/null || true
    tc filter add dev "$iface" parent 1: protocol ip prio 1 u32 \
        match ip dst 192.168.201.20/32 flowid 1:50 2>/dev/null || true

    # CPE-3 y CPE-4 (192.168.201.30-49) -> Plan Estándar (25M)
    tc filter add dev "$iface" parent 1: protocol ip prio 1 u32 \
        match ip dst 192.168.201.30/32 flowid 1:40 2>/dev/null || true
    tc filter add dev "$iface" parent 1: protocol ip prio 1 u32 \
        match ip dst 192.168.201.40/32 flowid 1:40 2>/dev/null || true

    # CPE-5 (192.168.201.50) -> Plan Premium (50M)
    tc filter add dev "$iface" parent 1: protocol ip prio 1 u32 \
        match ip dst 192.168.201.50/32 flowid 1:30 2>/dev/null || true

    # CPE-6 (192.168.201.60) -> Plan Ultra (100M)
    tc filter add dev "$iface" parent 1: protocol ip prio 1 u32 \
        match ip dst 192.168.201.60/32 flowid 1:20 2>/dev/null || true

    # Tráfico DSCP EF (VoIP) -> Prioritario
    tc filter add dev "$iface" parent 1: protocol ip prio 0 u32 \
        match ip tos 0xb8 0xff flowid 1:10 2>/dev/null || true

    echo "[INFO] IP filters created for 6 CPEs"
}

# =============================================================================
# Función: Mostrar estadísticas de QoS
# =============================================================================
show_qos_stats() {
    local iface=$1

    echo ""
    echo "=========================================="
    echo "QoS Statistics - $iface"
    echo "=========================================="

    echo ""
    echo "--- Qdisc Configuration ---"
    tc -s qdisc show dev "$iface" 2>/dev/null || echo "No qdisc configured"

    echo ""
    echo "--- Class Statistics ---"
    tc -s class show dev "$iface" 2>/dev/null || echo "No classes configured"

    echo ""
    echo "--- Filter Rules ---"
    tc filter show dev "$iface" 2>/dev/null || echo "No filters configured"
}

# =============================================================================
# Main: Aplicar configuración
# =============================================================================

echo ""
echo "[STEP 1] Applying HTB + fq_codel hierarchy..."
apply_htb_cake "$IFACE"

echo ""
echo "[STEP 2] Creating subscriber filters..."
create_ip_filters "$IFACE"

echo ""
echo "[STEP 3] Verifying configuration..."
show_qos_stats "$IFACE"

echo ""
echo "=========================================="
echo "QoS Configuration Complete!"
echo "=========================================="
echo ""
echo "Service Plans Applied:"
echo "  - CPE-1, CPE-2 (192.168.201.10, .20): Plan Básico  (10 Mbps)"
echo "  - CPE-3, CPE-4 (192.168.201.30, .40): Plan Estándar (25 Mbps)"
echo "  - CPE-5        (192.168.201.50):      Plan Premium  (50 Mbps)"
echo "  - CPE-6        (192.168.201.60):      Plan Ultra    (100 Mbps)"
echo ""
echo "Useful commands:"
echo "  tc -s qdisc show dev $IFACE    # Show qdisc stats"
echo "  tc -s class show dev $IFACE    # Show class stats"
echo "  tc filter show dev $IFACE      # Show filters"
echo ""

# Iniciar tc-exporter si existe
if [ -f /tc-exporter.sh ]; then
    echo "[INFO] Starting tc-exporter on port 9100..."
    /bin/sh /tc-exporter.sh 9100 "$IFACE" &
fi

# Mantener el contenedor corriendo
echo "[INFO] QoS Shaper running. Press Ctrl+C to stop."
exec tail -f /dev/null
