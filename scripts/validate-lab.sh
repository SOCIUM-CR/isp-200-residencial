#!/bin/bash
# =============================================================================
# Validacion del Laboratorio ISP-200
# =============================================================================

set -e

echo "========================================"
echo "  ISP-200 Lab Validation"
echo "========================================"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# 1. Verificar que los contenedores estan corriendo
echo ""
echo "1. Verificando contenedores..."
CONTAINERS=(
    "clab-isp-200-upstream-sim"
    "clab-isp-200-edge-router"
    "clab-isp-200-core-router"
    "clab-isp-200-agg-1"
    "clab-isp-200-agg-2"
    "clab-isp-200-acc-1"
    "clab-isp-200-acc-2"
    "clab-isp-200-acc-3"
    "clab-isp-200-cgnat-router"
    "clab-isp-200-bng-pppoe"
    "clab-isp-200-radius"
    "clab-isp-200-prometheus"
    "clab-isp-200-grafana"
)

for c in "${CONTAINERS[@]}"; do
    if docker ps --format '{{.Names}}' | grep -q "^${c}$"; then
        pass "$c running"
    else
        fail "$c not running"
    fi
done

# 2. Verificar BGP entre upstream y edge
echo ""
echo "2. Verificando BGP..."
BGP_STATUS=$(docker exec clab-isp-200-edge-router vtysh -c "show bgp summary" 2>/dev/null | grep -c "65000" || echo "0")
if [ "$BGP_STATUS" -gt "0" ]; then
    pass "BGP session con upstream (AS 65000) establecida"
else
    fail "BGP session no establecida"
fi

# 3. Verificar OSPF
echo ""
echo "3. Verificando OSPF..."
OSPF_NEIGHBORS=$(docker exec clab-isp-200-core-router vtysh -c "show ip ospf neighbor" 2>/dev/null | grep -c "Full" || echo "0")
if [ "$OSPF_NEIGHBORS" -ge "3" ]; then
    pass "OSPF: $OSPF_NEIGHBORS vecinos en estado Full"
else
    warn "OSPF: Solo $OSPF_NEIGHBORS vecinos en Full (esperado >= 3)"
fi

# 4. Verificar conectividad desde CPE
echo ""
echo "4. Verificando conectividad desde CPE..."
for i in 1 2 3; do
    if docker exec clab-isp-200-cpe-$i ping -c 1 -W 2 10.255.255.10 >/dev/null 2>&1; then
        pass "CPE-$i puede alcanzar edge-router"
    else
        fail "CPE-$i no puede alcanzar edge-router"
    fi
done

# 5. Verificar CGNAT
echo ""
echo "5. Verificando CGNAT..."
if docker exec clab-isp-200-cgnat-router nft list ruleset 2>/dev/null | grep -q "snat"; then
    pass "Reglas CGNAT cargadas"
else
    warn "Reglas CGNAT no encontradas (puede usar iptables)"
fi

# 6. Verificar servicios de monitoreo
echo ""
echo "6. Verificando servicios..."
if curl -s http://localhost:9090/-/healthy >/dev/null 2>&1; then
    pass "Prometheus accesible en http://localhost:9090"
else
    warn "Prometheus no accesible"
fi

if curl -s http://localhost:3000/api/health >/dev/null 2>&1; then
    pass "Grafana accesible en http://localhost:3000"
else
    warn "Grafana no accesible"
fi

# 7. Mostrar rutas BGP
echo ""
echo "7. Rutas BGP en edge-router:"
docker exec clab-isp-200-edge-router vtysh -c "show ip route bgp" 2>/dev/null || warn "No se pudo obtener rutas BGP"

echo ""
echo "========================================"
echo "  Validacion completada"
echo "========================================"
