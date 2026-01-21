#!/bin/sh
# =============================================================================
# CGNAT Router Setup Script
# =============================================================================

echo "[CGNAT] Configurando router CGNAT..."

# Instalar paquetes necesarios
apk update
apk add --no-cache nftables iptables iproute2

# Habilitar IP forwarding
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# Aumentar limites de conntrack para CGNAT
sysctl -w net.netfilter.nf_conntrack_max=262144
sysctl -w net.netfilter.nf_conntrack_tcp_timeout_established=3600
sysctl -w net.netfilter.nf_conntrack_udp_timeout=60

# Configurar interfaces
ip addr add 10.0.2.2/30 dev eth1 2>/dev/null || true
ip addr add 203.0.113.254/24 dev eth2 2>/dev/null || true

# Ruta default hacia upstream
ip route add default via 203.0.113.1 dev eth2 2>/dev/null || true

# Ruta hacia redes de suscriptores via core
ip route add 100.64.0.0/16 via 10.0.2.1 dev eth1 2>/dev/null || true

# Cargar configuracion nftables
if [ -f /etc/nftables.conf ]; then
    nft -f /etc/nftables.conf
    echo "[CGNAT] nftables configurado correctamente"
else
    echo "[CGNAT] WARN: /etc/nftables.conf no encontrado, usando iptables basico"
    # Fallback a iptables si nftables falla
    iptables -t nat -A POSTROUTING -s 100.64.0.0/16 -o eth2 -j MASQUERADE
fi

echo "[CGNAT] Setup completado"

# Mantener contenedor corriendo
tail -f /dev/null
