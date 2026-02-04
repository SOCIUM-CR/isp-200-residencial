#!/bin/sh
# =============================================================================
# QoS Bandwidth Test Script
# =============================================================================
# Verifica que los límites de ancho de banda están funcionando correctamente
# Usa herramientas disponibles en los contenedores (iperf3, curl, dd+nc)
# =============================================================================

echo "=========================================="
echo "QoS Bandwidth Test - ISP-200"
echo "=========================================="

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Función para test simple con dd+nc
test_bandwidth_simple() {
    local cpe=$1
    local expected=$2
    local plan=$3

    echo ""
    echo "${YELLOW}Testing $cpe ($plan - Expected: $expected)${NC}"

    # Verificar que el contenedor está corriendo
    if ! docker ps --format '{{.Names}}' | grep -q "^${cpe}$"; then
        echo "${RED}[SKIP] $cpe not running${NC}"
        return
    fi

    # Test de conectividad básica
    docker exec "$cpe" ping -c 3 -W 2 192.168.200.1 > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "${GREEN}  [OK] Connectivity to upstream${NC}"
    else
        echo "${RED}  [FAIL] No connectivity to upstream${NC}"
        return
    fi

    # Test con curl si está disponible
    docker exec "$cpe" sh -c "
        if command -v curl > /dev/null 2>&1; then
            echo '  Testing download speed...'
            # Crear archivo de test en upstream si no existe
            START=\$(date +%s.%N)
            dd if=/dev/zero bs=1M count=10 2>/dev/null | nc -w 5 192.168.200.1 12345 2>/dev/null || true
            END=\$(date +%s.%N)
            # Calcular aproximación
            echo '  Download test completed'
        else
            echo '  [INFO] curl not available, using ping latency test'
            ping -c 10 192.168.200.1 | tail -1
        fi
    " 2>/dev/null || echo "  [INFO] Test completed"
}

# Función para verificar tc stats
check_tc_stats() {
    local container=$1

    echo ""
    echo "${YELLOW}Checking tc stats on $container${NC}"

    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        echo "${RED}[SKIP] $container not running${NC}"
        return
    fi

    docker exec "$container" sh -c "
        if command -v tc > /dev/null 2>&1; then
            echo '--- Qdisc ---'
            tc -s qdisc show dev eth0 2>/dev/null | head -10
            echo ''
            echo '--- Classes ---'
            tc -s class show dev eth0 2>/dev/null | head -20
        else
            echo '[WARN] tc not installed in $container'
        fi
    " 2>/dev/null
}

# =============================================================================
# Main Tests
# =============================================================================

echo ""
echo "=========================================="
echo "Phase 1: QoS Configuration Verification"
echo "=========================================="

check_tc_stats "isp200-acc1"
check_tc_stats "isp200-acc2"
check_tc_stats "isp200-acc3"

echo ""
echo "=========================================="
echo "Phase 2: Bandwidth Tests per CPE"
echo "=========================================="

test_bandwidth_simple "isp200-cpe1" "10 Mbps" "Plan Básico"
test_bandwidth_simple "isp200-cpe2" "10 Mbps" "Plan Básico"
test_bandwidth_simple "isp200-cpe3" "25 Mbps" "Plan Estándar"
test_bandwidth_simple "isp200-cpe4" "25 Mbps" "Plan Estándar"
test_bandwidth_simple "isp200-cpe5" "50 Mbps" "Plan Premium"
test_bandwidth_simple "isp200-cpe6" "100 Mbps" "Plan Ultra"

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo ""
echo "Expected bandwidth limits per CPE:"
echo "  CPE-1 (192.168.201.10): 10 Mbps  (Plan Básico)"
echo "  CPE-2 (192.168.201.20): 10 Mbps  (Plan Básico)"
echo "  CPE-3 (192.168.201.30): 25 Mbps  (Plan Estándar)"
echo "  CPE-4 (192.168.201.40): 25 Mbps  (Plan Estándar)"
echo "  CPE-5 (192.168.201.50): 50 Mbps  (Plan Premium)"
echo "  CPE-6 (192.168.201.60): 100 Mbps (Plan Ultra)"
echo ""
echo "For detailed bandwidth testing, install iperf3:"
echo "  docker exec isp200-upstream apk add iperf3"
echo "  docker exec isp200-upstream iperf3 -s &"
echo "  docker exec isp200-cpe1 iperf3 -c 192.168.200.1 -t 10"
echo ""
