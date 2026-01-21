# Guía de Operaciones - ISP-200 Residencial

## Índice

1. [Gestión del Laboratorio](#gestión-del-laboratorio)
2. [Acceso a Dispositivos](#acceso-a-dispositivos)
3. [Comandos de Verificación](#comandos-de-verificación)
4. [Troubleshooting](#troubleshooting)
5. [Escenarios de Práctica](#escenarios-de-práctica)

---

## Gestión del Laboratorio

### Iniciar el Laboratorio

```bash
cd /Users/francomicalizzi/Downloads/Claude/container-labs-project/labs/isp-200-residencial

# Iniciar todos los servicios
docker compose up -d

# Verificar que todo esté corriendo
docker compose ps
```

### Detener el Laboratorio

```bash
# Detener sin eliminar datos
docker compose stop

# Detener y eliminar contenedores
docker compose down

# Detener y eliminar TODO (incluyendo redes y volúmenes)
docker compose down --volumes --remove-orphans
```

### Reiniciar Servicios Específicos

```bash
# Reiniciar un router específico
docker compose restart edge-router

# Reiniciar el stack de monitoreo
docker compose restart prometheus grafana

# Reiniciar generador de tráfico
docker compose restart traffic-gen
```

### Ver Logs

```bash
# Logs de un contenedor específico
docker logs isp200-edge

# Logs en tiempo real
docker logs -f isp200-edge

# Logs de los últimos 5 minutos
docker logs --since 5m isp200-edge

# Logs de todos los servicios
docker compose logs
```

---

## Acceso a Dispositivos

### Routers FRRouting

```bash
# Edge Router (BGP + OSPF)
docker exec -it isp200-edge vtysh

# Core Router
docker exec -it isp200-core vtysh

# Aggregation Routers
docker exec -it isp200-agg1 vtysh
docker exec -it isp200-agg2 vtysh

# Access Routers
docker exec -it isp200-acc1 vtysh
docker exec -it isp200-acc2 vtysh
docker exec -it isp200-acc3 vtysh

# Upstream (simulador de Internet)
docker exec -it isp200-upstream vtysh
```

### CPEs (Clientes)

```bash
# Acceso a shell
docker exec -it isp200-cpe1 sh
docker exec -it isp200-cpe2 sh
# ... etc

# Ejecutar comando directo
docker exec isp200-cpe1 ping -c 3 192.168.200.1
```

### CGNAT Router

```bash
# Shell de Alpine
docker exec -it isp200-cgnat sh

# Ver reglas NAT
docker exec isp200-cgnat nft list ruleset
```

---

## Comandos de Verificación

### BGP

```bash
# Resumen de sesiones BGP
docker exec isp200-edge vtysh -c "show bgp summary"

# Rutas BGP recibidas
docker exec isp200-edge vtysh -c "show bgp ipv4 unicast"

# Detalle de un vecino BGP
docker exec isp200-edge vtysh -c "show bgp neighbors 192.168.200.1"

# Rutas anunciadas a un vecino
docker exec isp200-edge vtysh -c "show bgp neighbors 192.168.200.1 advertised-routes"

# Rutas recibidas de un vecino
docker exec isp200-edge vtysh -c "show bgp neighbors 192.168.200.1 received-routes"
```

### OSPF

```bash
# Vecinos OSPF
docker exec isp200-core vtysh -c "show ip ospf neighbor"

# Interfaces OSPF
docker exec isp200-core vtysh -c "show ip ospf interface"

# Base de datos OSPF
docker exec isp200-core vtysh -c "show ip ospf database"

# Rutas OSPF
docker exec isp200-core vtysh -c "show ip route ospf"
```

### Tabla de Routing

```bash
# Tabla completa
docker exec isp200-edge vtysh -c "show ip route"

# Solo rutas BGP
docker exec isp200-edge vtysh -c "show ip route bgp"

# Solo rutas OSPF
docker exec isp200-core vtysh -c "show ip route ospf"

# Solo rutas conectadas
docker exec isp200-core vtysh -c "show ip route connected"
```

### Interfaces

```bash
# Estado de interfaces
docker exec isp200-edge vtysh -c "show interface brief"

# Detalle de una interfaz
docker exec isp200-edge vtysh -c "show interface eth0"
```

### Conectividad

```bash
# Ping desde CPE a Internet simulado
docker exec isp200-cpe1 ping -c 3 192.168.200.1

# Traceroute completo
docker exec isp200-cpe1 traceroute -n 192.168.200.1

# Verificar DNS (si hubiera)
docker exec isp200-cpe1 nslookup google.com 8.8.8.8
```

---

## Troubleshooting

### BGP no establece sesión

**Síntomas**: `show bgp summary` muestra estado "Active" o "Connect"

**Diagnóstico**:
```bash
# 1. Verificar conectividad IP
docker exec isp200-edge ping -c 3 192.168.200.1

# 2. Verificar configuración
docker exec isp200-edge vtysh -c "show running-config | section bgp"

# 3. Ver logs
docker logs isp200-edge 2>&1 | grep -i bgp
```

**Soluciones comunes**:
- Verificar que `no bgp ebgp-requires-policy` esté configurado
- Verificar ASN correcto en ambos lados
- Verificar que las IPs de vecino sean correctas

### OSPF no forma Full adjacency

**Síntomas**: Vecinos en estado "2-Way" o "ExStart"

**Diagnóstico**:
```bash
# 1. Verificar interfaces
docker exec isp200-core vtysh -c "show ip ospf interface"

# 2. Ver base de datos
docker exec isp200-core vtysh -c "show ip ospf database"
```

**Soluciones comunes**:
- En redes broadcast, estado 2-Way es normal para non-DR/BDR
- Verificar que las redes estén en la misma área
- Verificar MTU match

### Sin conectividad entre CPE e Internet

**Diagnóstico paso a paso**:
```bash
# 1. CPE → Access Router
docker exec isp200-cpe1 ping -c 2 192.168.200.20

# 2. CPE → Core Router
docker exec isp200-cpe1 ping -c 2 192.168.200.3

# 3. CPE → Edge Router
docker exec isp200-cpe1 ping -c 2 192.168.200.2

# 4. CPE → Upstream
docker exec isp200-cpe1 ping -c 2 192.168.200.1

# 5. Verificar ruta default en CPE
docker exec isp200-cpe1 ip route

# 6. Traceroute para ver dónde falla
docker exec isp200-cpe1 traceroute -n 192.168.200.1
```

### Contenedor no inicia

```bash
# Ver logs del contenedor
docker logs isp200-<nombre>

# Ver estado detallado
docker inspect isp200-<nombre>

# Intentar reiniciar
docker compose restart <servicio>

# Recrear contenedor
docker compose up -d --force-recreate <servicio>
```

---

## Escenarios de Práctica

### Escenario 1: Falla de Upstream

Simular pérdida de conectividad con el proveedor de tránsito.

```bash
# Detener upstream
docker compose stop upstream-sim

# Verificar que BGP cae
docker exec isp200-edge vtysh -c "show bgp summary"

# Restaurar
docker compose start upstream-sim

# Verificar recuperación
watch -n 2 'docker exec isp200-edge vtysh -c "show bgp summary"'
```

### Escenario 2: Falla de Core Router

```bash
# Detener core
docker compose stop core-router

# Verificar impacto en OSPF
docker exec isp200-agg1 vtysh -c "show ip ospf neighbor"

# Restaurar
docker compose start core-router
```

### Escenario 3: Agregar Nuevo CPE

```bash
# Crear CPE temporal
docker run -d --name isp200-cpe-temp \
  --network isp-200-residencial_isp-internal \
  --ip 192.168.201.70 \
  --privileged \
  wbitt/network-multitool:alpine-extra

# Probar conectividad
docker exec isp200-cpe-temp ping -c 3 192.168.200.1

# Eliminar cuando termine
docker rm -f isp200-cpe-temp
```

### Escenario 4: Cambiar Política BGP

```bash
# Acceder a edge router
docker exec -it isp200-edge vtysh

# Entrar en modo configuración
configure terminal

# Agregar prefix-list
ip prefix-list DENY-DEFAULT seq 5 deny 0.0.0.0/0
ip prefix-list DENY-DEFAULT seq 10 permit any

# Aplicar a vecino
router bgp 65100
 address-family ipv4 unicast
  neighbor 192.168.200.1 prefix-list DENY-DEFAULT in

# Salir y guardar
end
write memory

# Verificar que ya no recibe default
show ip route bgp
```

---

## Comandos Útiles Combinados

### One-liner: Estado completo del lab

```bash
echo "=== BGP ===" && \
docker exec isp200-edge vtysh -c "show bgp summary" && \
echo "=== OSPF ===" && \
docker exec isp200-core vtysh -c "show ip ospf neighbor" && \
echo "=== Conectividad ===" && \
docker exec isp200-cpe1 ping -c 2 192.168.200.1
```

### Monitoreo continuo de BGP

```bash
watch -n 5 'docker exec isp200-edge vtysh -c "show bgp summary"'
```

### Captura de tráfico

```bash
# En el edge router
docker exec isp200-edge tcpdump -i eth0 -n -c 100

# Solo BGP
docker exec isp200-edge tcpdump -i eth0 -n port 179

# Solo OSPF
docker exec isp200-core tcpdump -i eth0 -n proto ospf
```
