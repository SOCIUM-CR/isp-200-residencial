# Configuración Técnica - ISP-200 Residencial

## Índice

1. [Docker Compose](#docker-compose)
2. [FRRouting](#frrouting)
3. [BGP](#bgp)
4. [OSPF](#ospf)
5. [CGNAT](#cgnat)
6. [Generador de Tráfico](#generador-de-tráfico)

---

## Docker Compose

### Red Principal

```yaml
networks:
  isp-internal:
    driver: bridge
    ipam:
      config:
        - subnet: 192.168.192.0/20
```

**Notas**:
- Red /20 permite 4094 hosts
- Todos los contenedores en la misma red Docker
- Comunicación directa entre todos los nodos

### Configuración de Contenedores FRR

```yaml
services:
  edge-router:
    image: quay.io/frrouting/frr:8.4.1
    container_name: isp200-edge
    hostname: edge-router
    privileged: true
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv6.conf.all.forwarding=1
    volumes:
      - ./configs/frr/edge-router/frr.conf:/etc/frr/frr.conf
      - ./configs/frr/edge-router/daemons:/etc/frr/daemons
    networks:
      isp-internal:
        ipv4_address: 192.168.200.2
```

**Parámetros clave**:
- `privileged: true`: Necesario para manipular routing
- `NET_ADMIN`: Capacidad para configurar interfaces
- `ip_forward=1`: Habilita routing de paquetes

---

## FRRouting

### Archivo daemons

Ubicación: `configs/frr/<router>/daemons`

```ini
zebra=yes      # Siempre requerido (gestión de interfaces)
bgpd=yes       # Solo en edge-router y upstream
ospfd=yes      # En todos los routers internos
staticd=yes    # Para rutas estáticas
bfdd=yes       # Bidirectional Forwarding Detection

vtysh_enable=yes
zebra_options="  -A 127.0.0.1 -s 90000000"
bgpd_options="   -A 127.0.0.1"
ospfd_options="  -A 127.0.0.1"
```

### Estructura de frr.conf

```
frr version 8.4.1
frr defaults traditional
hostname <nombre-router>
log syslog informational
service integrated-vtysh-config
!
interface lo
 ip address 10.255.255.X/32
!
! Configuración de protocolos...
!
line vty
!
```

---

## BGP

### Upstream Simulator (AS 65000)

```
router bgp 65000
 bgp router-id 10.255.255.1
 no bgp ebgp-requires-policy
 bgp log-neighbor-changes
 !
 neighbor 192.168.200.2 remote-as 65100
 neighbor 192.168.200.2 description "ISP-200 Edge Router"
 !
 address-family ipv4 unicast
  network 0.0.0.0/0
  neighbor 192.168.200.2 activate
  neighbor 192.168.200.2 soft-reconfiguration inbound
 exit-address-family
```

**Explicación**:
- `no bgp ebgp-requires-policy`: Permite anuncios sin route-maps (requerido en FRR 8.x+)
- `network 0.0.0.0/0`: Anuncia ruta default (simula Internet)
- `soft-reconfiguration inbound`: Permite ver rutas recibidas sin reset

### Edge Router ISP (AS 65100)

```
router bgp 65100
 bgp router-id 10.255.255.10
 no bgp ebgp-requires-policy
 bgp log-neighbor-changes
 !
 neighbor 192.168.200.1 remote-as 65000
 neighbor 192.168.200.1 description "Upstream Transit Provider"
 !
 address-family ipv4 unicast
  network 192.168.192.0/20
  neighbor 192.168.200.1 activate
  neighbor 192.168.200.1 soft-reconfiguration inbound
 exit-address-family
```

**Explicación**:
- `network 192.168.192.0/20`: Anuncia el bloque del ISP al upstream
- Recibe 0.0.0.0/0 del upstream

### Verificación BGP

```bash
# Acceder al router
docker exec -it isp200-edge vtysh

# Comandos útiles
show bgp summary
show bgp ipv4 unicast
show bgp neighbors 192.168.200.1
show ip route bgp
```

---

## OSPF

### Configuración Core Router

```
router ospf
 ospf router-id 10.255.255.11
 network 10.255.255.11/32 area 0
 network 192.168.192.0/20 area 0
```

### Configuración Access Router

```
router ospf
 ospf router-id 10.255.255.30
 network 10.255.255.30/32 area 0
 network 192.168.192.0/20 area 0
```

### Áreas OSPF

| Área | Routers | Función |
|------|---------|---------|
| 0 | edge, core, agg-1, agg-2 | Backbone |
| 1 | acc-1, acc-2 | Zona Norte (futuro) |
| 2 | acc-3 | Zona Sur (futuro) |

### Verificación OSPF

```bash
docker exec -it isp200-core vtysh

# Comandos útiles
show ip ospf neighbor
show ip ospf interface
show ip ospf database
show ip route ospf
```

---

## CGNAT

### Conceptos

**CGNAT (Carrier-Grade NAT)** permite compartir direcciones IPv4 públicas entre múltiples usuarios usando el rango RFC 6598 (100.64.0.0/10).

En este lab, simulamos CGNAT aunque usamos direcciones privadas.

### Configuración nftables

Ubicación: `configs/cgnat/nftables.conf`

```nft
#!/usr/sbin/nft -f

flush ruleset

table ip nat {
    chain postrouting {
        type nat hook postrouting priority srcnat;

        # CGNAT: Tráfico de suscriptores hacia Internet
        ip saddr 192.168.201.0/24 oifname "eth0" masquerade
    }
}

table ip filter {
    chain forward {
        type filter hook forward priority filter;
        policy accept;

        ct state established,related accept
        ip saddr 192.168.201.0/24 accept
    }
}
```

### Script de Setup

Ubicación: `scripts/setup-cgnat.sh`

```bash
#!/bin/sh
apk update
apk add --no-cache nftables iptables iproute2

sysctl -w net.ipv4.ip_forward=1
sysctl -w net.netfilter.nf_conntrack_max=262144

# Cargar nftables o fallback a iptables
nft -f /etc/nftables.conf || \
    iptables -t nat -A POSTROUTING -s 192.168.201.0/24 -j MASQUERADE

tail -f /dev/null  # Mantener contenedor corriendo
```

### Verificación CGNAT

```bash
# Ver reglas NAT
docker exec isp200-cgnat nft list ruleset

# Ver conexiones activas
docker exec isp200-cgnat cat /proc/net/nf_conntrack | head
```

---

## Generador de Tráfico

### Propósito

Simular actividad de usuarios para generar métricas visibles en el monitoreo.

### Script

Ubicación: `scripts/traffic-generator.sh`

```bash
#!/bin/sh

while true; do
    # Ping a routers
    ping -c 5 -i 0.2 192.168.200.1 > /dev/null 2>&1 &
    ping -c 5 -i 0.2 192.168.200.2 > /dev/null 2>&1 &

    # Ping a CPEs
    for cpe in 192.168.201.10 192.168.201.20 192.168.201.30; do
        ping -c 3 -i 0.1 $cpe > /dev/null 2>&1 &
    done

    # HTTP simulado
    curl -s -o /dev/null http://192.168.200.1/ 2>/dev/null &

    # Transferencia de datos
    dd if=/dev/zero bs=1M count=5 | nc -w 2 192.168.200.1 12345 &

    wait
    sleep 2
done
```

### Tipos de Tráfico Generado

| Tipo | Destino | Frecuencia |
|------|---------|------------|
| ICMP (ping) | Routers, CPEs | Cada 2-3 seg |
| HTTP | Upstream, Edge | Cada 2-3 seg |
| Bulk data | Upstream | Cada 2-3 seg |

---

## Archivos de Configuración

### Estructura Completa

```
configs/
├── frr/
│   ├── upstream-sim/
│   │   ├── daemons          # Demonios habilitados
│   │   └── frr.conf         # BGP AS 65000
│   ├── edge-router/
│   │   ├── daemons
│   │   └── frr.conf         # BGP AS 65100 + OSPF
│   ├── core-router/
│   │   ├── daemons
│   │   └── frr.conf         # OSPF backbone
│   ├── agg-1/
│   │   ├── daemons
│   │   └── frr.conf         # OSPF
│   ├── agg-2/
│   │   ├── daemons
│   │   └── frr.conf         # OSPF
│   ├── acc-1/
│   │   ├── daemons
│   │   └── frr.conf         # OSPF
│   ├── acc-2/
│   │   ├── daemons
│   │   └── frr.conf         # OSPF
│   └── acc-3/
│       ├── daemons
│       └── frr.conf         # OSPF
├── cgnat/
│   └── nftables.conf        # Reglas NAT
├── pppoe/
│   └── accel-ppp.conf       # Referencia (no activo)
├── radius/
│   ├── clients.conf         # Referencia (no activo)
│   └── users                # Referencia (no activo)
└── monitoring/
    └── prometheus.yml       # Scrape config
```

---

## Troubleshooting de Configuración

### BGP no establece sesión

```bash
# Verificar conectividad básica
docker exec isp200-edge ping -c 3 192.168.200.1

# Ver estado detallado
docker exec isp200-edge vtysh -c "show bgp neighbors 192.168.200.1"

# Ver logs
docker logs isp200-edge 2>&1 | grep -i bgp
```

### OSPF no forma adyacencias

```bash
# Verificar interfaces OSPF
docker exec isp200-core vtysh -c "show ip ospf interface"

# Ver base de datos
docker exec isp200-core vtysh -c "show ip ospf database"
```

### Tráfico no fluye

```bash
# Verificar rutas
docker exec isp200-edge vtysh -c "show ip route"

# Verificar forwarding
docker exec isp200-edge sysctl net.ipv4.ip_forward

# Traceroute
docker exec isp200-cpe1 traceroute 192.168.200.1
```
