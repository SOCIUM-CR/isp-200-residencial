#!/bin/bash
# =============================================================================
# Configurar CPEs con IPs estaticas (simulacion DHCP)
# =============================================================================

echo "Configurando CPEs..."

# CPE-1: Sector A, segmento 1
docker exec clab-isp-200-cpe-1 sh -c "
    ip addr flush dev eth1
    ip addr add 100.64.1.10/24 dev eth1
    ip route add default via 100.64.1.1
    echo 'CPE-1 configurado: 100.64.1.10/24'
"

# CPE-2: Sector A, segmento 2
docker exec clab-isp-200-cpe-2 sh -c "
    ip addr flush dev eth1
    ip addr add 100.64.2.10/24 dev eth1
    ip route add default via 100.64.2.1
    echo 'CPE-2 configurado: 100.64.2.10/24'
"

# CPE-3: Sector B, segmento 3
docker exec clab-isp-200-cpe-3 sh -c "
    ip addr flush dev eth1
    ip addr add 100.64.3.10/24 dev eth1
    ip route add default via 100.64.3.1
    echo 'CPE-3 configurado: 100.64.3.10/24'
"

# CPE-4: Sector B, segmento 4
docker exec clab-isp-200-cpe-4 sh -c "
    ip addr flush dev eth1
    ip addr add 100.64.4.10/24 dev eth1
    ip route add default via 100.64.4.1
    echo 'CPE-4 configurado: 100.64.4.10/24'
"

# CPE-5: Sector C, segmento 5
docker exec clab-isp-200-cpe-5 sh -c "
    ip addr flush dev eth1
    ip addr add 100.64.5.10/24 dev eth1
    ip route add default via 100.64.5.1
    echo 'CPE-5 configurado: 100.64.5.10/24'
"

# CPE-6: Sector C, segmento 6
docker exec clab-isp-200-cpe-6 sh -c "
    ip addr flush dev eth1
    ip addr add 100.64.6.10/24 dev eth1
    ip route add default via 100.64.6.1
    echo 'CPE-6 configurado: 100.64.6.10/24'
"

echo ""
echo "Todos los CPEs configurados."
echo "Probando conectividad..."
echo ""

for i in 1 2 3 4 5 6; do
    echo "CPE-$i -> Edge Router (10.255.255.10):"
    docker exec clab-isp-200-cpe-$i ping -c 2 -W 1 10.255.255.10 2>/dev/null && echo "  OK" || echo "  FAIL"
done
