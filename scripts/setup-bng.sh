#!/bin/sh
# =============================================================================
# BNG/BRAS Setup Script (accel-ppp)
# =============================================================================

echo "[BNG] Configurando BNG/BRAS con accel-ppp..."

# Nota: En un entorno real se usaria una imagen con accel-ppp preinstalado
# Este script simula la funcionalidad basica del BNG

# Instalar paquetes necesarios
apk update
apk add --no-cache iproute2 iptables ppp

# Habilitar IP forwarding
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# Configurar interfaces
ip addr add 10.0.1.2/30 dev eth1 2>/dev/null || true
ip addr add 100.64.100.1/22 dev eth1:1 2>/dev/null || true

# Configurar interfaz hacia RADIUS
ip addr add 192.168.50.1/24 dev eth2 2>/dev/null || true

# Crear directorio de logs
mkdir -p /var/log/accel-ppp

# Rutas
# Ruta hacia core para alcanzar todo el ISP
ip route add 10.0.0.0/8 via 10.0.1.1 dev eth1 2>/dev/null || true
# Ruta hacia CGNAT para trafico de suscriptores a Internet
ip route add default via 10.0.1.1 dev eth1 2>/dev/null || true

echo "[BNG] Configuracion de red completada"
echo "[BNG] NOTA: accel-ppp requiere imagen especializada para funcionalidad completa"
echo "[BNG] Pool PPPoE: 100.64.100.2-100.64.103.254"
echo "[BNG] Gateway: 100.64.100.1"

# Log de configuracion
cat << 'EOF' > /var/log/accel-ppp/status.log
BNG Status: READY
Pool: 100.64.100.0/22 (1022 IPs)
RADIUS: 172.20.0.50:1812/1813
MTU: 1492
DNS1: 8.8.8.8
DNS2: 8.8.4.4
EOF

# Mantener contenedor corriendo
tail -f /dev/null
