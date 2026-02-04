#!/bin/sh
# =============================================================================
# Apply QoS to Access Layer Routers (acc-1, acc-2, acc-3)
# =============================================================================
# Este script aplica traffic shaping directamente en los routers de acceso
# que es donde típicamente se configura QoS en un ISP real
# =============================================================================

set -e

echo "=========================================="
echo "Applying QoS to Access Layer Routers"
echo "=========================================="

# Función para aplicar QoS en un contenedor específico
apply_qos_to_container() {
    local container=$1
    local subscriber_ip=$2
    local download=$3
    local upload=$4
    local plan_name=$5

    echo ""
    echo "[INFO] Configuring $container for $subscriber_ip ($plan_name: $download down / $upload up)"

    # Verificar que el contenedor está corriendo
    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        echo "[WARN] Container $container not running, skipping..."
        return 1
    fi

    # Instalar tc si no está disponible (FRR Alpine base)
    docker exec "$container" sh -c "
        if ! command -v tc > /dev/null 2>&1; then
            apk add --no-cache iproute2 iproute2-tc 2>/dev/null || true
        fi
    " 2>/dev/null || true

    # Aplicar QoS
    docker exec "$container" sh -c "
        IFACE=eth0

        # Limpiar configuración existente
        tc qdisc del dev \$IFACE root 2>/dev/null || true

        # Crear HTB qdisc
        tc qdisc add dev \$IFACE root handle 1: htb default 10

        # Clase raíz
        tc class add dev \$IFACE parent 1: classid 1:1 htb rate 1gbit ceil 1gbit burst 15k

        # Clase para el suscriptor
        tc class add dev \$IFACE parent 1:1 classid 1:10 htb rate $download ceil $download burst 15k

        # AQM con fq_codel
        tc qdisc add dev \$IFACE parent 1:10 handle 10: fq_codel limit 10240 target 5ms interval 100ms ecn

        # Filtro por IP destino
        tc filter add dev \$IFACE parent 1: protocol ip prio 1 u32 match ip dst $subscriber_ip/32 flowid 1:10

        echo 'QoS applied successfully'
    " 2>/dev/null

    echo "[OK] $container configured"
}

# =============================================================================
# Aplicar QoS a cada router de acceso
# =============================================================================

echo ""
echo "--- ACC-1 (Sector A - Zona económica) ---"
# acc-1 sirve a CPE-1 y CPE-2 (Plan Básico)
apply_qos_to_container "isp200-acc1" "192.168.201.10" "10mbit" "2mbit" "Básico"
apply_qos_to_container "isp200-acc1" "192.168.201.20" "10mbit" "2mbit" "Básico"

echo ""
echo "--- ACC-2 (Sector B - Zona media) ---"
# acc-2 sirve a CPE-3 y CPE-4 (Plan Estándar)
apply_qos_to_container "isp200-acc2" "192.168.201.30" "25mbit" "5mbit" "Estándar"
apply_qos_to_container "isp200-acc2" "192.168.201.40" "25mbit" "5mbit" "Estándar"

echo ""
echo "--- ACC-3 (Sector C - Zona premium) ---"
# acc-3 sirve a CPE-5 (Premium) y CPE-6 (Ultra)
apply_qos_to_container "isp200-acc3" "192.168.201.50" "50mbit" "10mbit" "Premium"
apply_qos_to_container "isp200-acc3" "192.168.201.60" "100mbit" "20mbit" "Ultra"

echo ""
echo "=========================================="
echo "QoS Configuration Complete!"
echo "=========================================="
echo ""
echo "To verify configuration:"
echo "  docker exec isp200-acc1 tc -s class show dev eth0"
echo "  docker exec isp200-acc2 tc -s class show dev eth0"
echo "  docker exec isp200-acc3 tc -s class show dev eth0"
echo ""
echo "To test bandwidth limiting:"
echo "  docker exec isp200-cpe1 iperf3 -c 192.168.200.1 -t 10"
echo ""
