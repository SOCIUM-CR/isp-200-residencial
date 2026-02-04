# QoS Implementation - tc + CAKE

## Visión General

Este documento describe la implementación de QoS (Quality of Service) en el laboratorio ISP-200 usando `tc` (traffic control) con algoritmos CAKE/fq_codel, como alternativa ligera a LibreQoS para entornos Docker/macOS.

---

## Arquitectura

```
                      ┌─────────────────┐
                      │   UPSTREAM      │
                      │  192.168.200.1  │
                      └────────┬────────┘
                               │
                      ┌────────┴────────┐
                      │   QOS-SHAPER    │  ◄── HTB + fq_codel
                      │  192.168.200.50 │      Traffic shaping centralizado
                      └────────┬────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                │
      ┌───────┴───────┐ ┌──────┴──────┐ ┌──────┴──────┐
      │    ACC-1      │ │   ACC-2     │ │   ACC-3     │
      │ (tc shaping)  │ │ (tc shaping)│ │ (tc shaping)│
      └───────┬───────┘ └──────┬──────┘ └──────┬──────┘
              │                │                │
       ┌──────┴──────┐  ┌──────┴──────┐  ┌──────┴──────┐
       │CPE-1  CPE-2 │  │CPE-3  CPE-4 │  │CPE-5  CPE-6 │
       │ 10M    10M  │  │ 25M    25M  │  │ 50M   100M  │
       └─────────────┘  └─────────────┘  └─────────────┘
```

---

## Planes de Servicio

| Plan | Download | Upload | Uso típico |
|------|----------|--------|------------|
| Básico | 10 Mbps | 2 Mbps | Navegación, email |
| Estándar | 25 Mbps | 5 Mbps | Streaming SD/HD |
| Premium | 50 Mbps | 10 Mbps | Gaming, 4K |
| Ultra | 100 Mbps | 20 Mbps | Trabajo remoto, múltiples usuarios |

### Asignación de Suscriptores

| CPE | IP | Plan | Sector |
|-----|-----|------|--------|
| CPE-1 | 192.168.201.10 | Básico (10M) | A (acc-1) |
| CPE-2 | 192.168.201.20 | Básico (10M) | A (acc-1) |
| CPE-3 | 192.168.201.30 | Estándar (25M) | B (acc-2) |
| CPE-4 | 192.168.201.40 | Estándar (25M) | B (acc-2) |
| CPE-5 | 192.168.201.50 | Premium (50M) | C (acc-3) |
| CPE-6 | 192.168.201.60 | Ultra (100M) | C (acc-3) |

---

## Componentes Técnicos

### HTB (Hierarchical Token Bucket)

Qdisc que permite crear jerarquías de clases con límites de bandwidth garantizado y máximo.

```
root (1:) - HTB
│
├── 1:1 - Clase raíz (1 Gbps)
│   │
│   ├── 1:10 - Prioritario (VoIP) - 100 Mbps
│   ├── 1:20 - Plan Ultra - 100 Mbps
│   ├── 1:30 - Plan Premium - 50 Mbps
│   ├── 1:40 - Plan Estándar - 25 Mbps (default)
│   └── 1:50 - Plan Básico - 10 Mbps
```

### fq_codel (Fair Queuing Controlled Delay)

AQM (Active Queue Management) que:
- Reduce bufferbloat
- Mantiene latencia baja
- Distribuye bandwidth equitativamente entre flujos

Parámetros:
- `target 5ms`: Latencia objetivo
- `interval 100ms`: Intervalo de medición
- `ecn`: Explicit Congestion Notification habilitado

### CAKE (Common Applications Kept Enhanced)

Algoritmo avanzado que combina:
- Shaping de bandwidth
- AQM (similar a fq_codel pero mejor)
- Fairness entre hosts
- Manejo de NAT

> **Nota**: CAKE requiere kernel Linux con módulo `sch_cake`. En Docker puede no estar disponible, por eso usamos fq_codel como fallback.

---

## Uso

### 1. Levantar el laboratorio con QoS

```bash
cd labs/isp-200-residencial
docker compose up -d
```

El contenedor `qos-shaper` se configura automáticamente al iniciar.

### 2. Aplicar QoS a routers de acceso

```bash
./scripts/apply-qos-access.sh
```

### 3. Verificar configuración

```bash
# Ver qdisc en qos-shaper
docker exec isp200-qos-shaper tc -s qdisc show dev eth0

# Ver clases
docker exec isp200-qos-shaper tc -s class show dev eth0

# Ver filtros
docker exec isp200-qos-shaper tc filter show dev eth0
```

### 4. Monitorear en tiempo real

```bash
docker exec -it isp200-qos-shaper /qos-monitor.sh
```

### 5. Test de bandwidth

```bash
# Test básico
./scripts/test-qos-bandwidth.sh

# Test con iperf3 (más preciso)
# Desde CPE-1 (debe dar ~10 Mbps)
docker exec isp200-cpe1 sh -c "apk add iperf3 && iperf3 -c 192.168.200.51 -t 10"

# Desde CPE-6 (debe dar ~100 Mbps)
docker exec isp200-cpe6 sh -c "apk add iperf3 && iperf3 -c 192.168.200.51 -t 10"
```

---

## Comandos tc Útiles

### Ver estadísticas

```bash
# Estadísticas de qdisc
tc -s qdisc show dev eth0

# Estadísticas de clases
tc -s class show dev eth0

# Ver filtros
tc filter show dev eth0
```

### Modificar en caliente

```bash
# Cambiar rate de una clase
tc class change dev eth0 parent 1:1 classid 1:50 htb rate 15mbit ceil 15mbit

# Agregar nuevo filtro
tc filter add dev eth0 parent 1: protocol ip prio 1 u32 \
    match ip dst 192.168.201.70/32 flowid 1:30

# Eliminar qdisc (reset)
tc qdisc del dev eth0 root
```

### Debug

```bash
# Ver en tiempo real (requiere watch)
watch -n 1 'tc -s class show dev eth0'

# Ver drops y overlimits
tc -s qdisc show dev eth0 | grep -E "dropped|overlimit"
```

---

## Comparación con LibreQoS

| Característica | tc + CAKE | LibreQoS |
|---------------|-----------|----------|
| Plataforma | Linux (Docker ok) | Linux (bare metal) |
| Arquitectura | x86_64, ARM64 | x86_64 solo |
| Throughput | ~1-5 Gbps | 10+ Gbps |
| NICs especiales | No | Sí (XDP) |
| UI Web | No | Sí |
| Integración UISP/Splynx | No | Sí |
| Per-subscriber shaping | Manual (filtros) | Automático |
| Complejidad | Baja | Media-Alta |
| Costo | Gratis | Gratis + soporte pago |

---

## Troubleshooting

### tc: command not found

```bash
# En Alpine
apk add iproute2 iproute2-tc

# En Debian/Ubuntu
apt install iproute2
```

### CAKE not available

```bash
# Verificar módulo
modprobe sch_cake

# Si falla, usar fq_codel (ya configurado como fallback)
```

### Filtros no funcionan

```bash
# Verificar que los filtros están en la tabla correcta
tc filter show dev eth0

# El tráfico debe coincidir con las reglas u32
# match ip dst X.X.X.X/32 para IP específica
```

### No se aplica el límite

```bash
# Verificar que el tráfico pasa por la interfaz correcta
# En Docker, eth0 es la interfaz de la red bridge

# Verificar counters
tc -s class show dev eth0 | grep -A 5 "1:50"
```

---

## Monitoreo con Grafana

### Dashboard QoS Traffic Shaping

Las métricas de tc/QoS se exportan automáticamente a Prometheus y se visualizan en Grafana.

**URL:** http://localhost:3000/d/qos-traffic-shaping/qos-traffic-shaping

**Credenciales:** admin / admin

### Paneles Disponibles

| Panel | Descripción | Métrica |
|-------|-------------|---------|
| QoS Traffic Rate by Class | Tráfico en bytes/sec por clase HTB | `rate(tc_class_bytes_total[1m])` |
| Dropped Packets by Class | Paquetes dropeados por shaping | `increase(tc_class_drops_total[1m])` |
| Overlimits by Class | Eventos de rate limiting | `increase(tc_class_overlimits_total[1m])` |
| Configured Rate Limits | Límites configurados | `tc_class_rate_bytes` |
| Configured Ceil Limits | Límites máximos burst | `tc_class_ceil_bytes` |
| Qdisc Total Traffic | Tráfico total del qdisc | `rate(tc_qdisc_bytes_total[1m])` |

### Métricas Prometheus Exportadas

```promql
# Contadores (usar con rate/increase)
tc_qdisc_bytes_total{interface, qdisc, handle}
tc_qdisc_packets_total{interface, qdisc, handle}
tc_qdisc_drops_total{interface, qdisc, handle}
tc_qdisc_overlimits_total{interface, qdisc, handle}
tc_class_bytes_total{interface, classid}
tc_class_packets_total{interface, classid}
tc_class_drops_total{interface, classid}
tc_class_overlimits_total{interface, classid}

# Gauges (valores directos)
tc_class_rate_bytes{interface, classid}
tc_class_ceil_bytes{interface, classid}
```

### Queries Útiles

```promql
# Tráfico por clase en Mbps
rate(tc_class_bytes_total[1m]) * 8 / 1000000

# Porcentaje de uso vs límite configurado
rate(tc_class_bytes_total[1m]) / tc_class_rate_bytes * 100

# Drops rate
rate(tc_class_drops_total[1m])
```

---

## Archivos de Configuración

| Archivo | Propósito |
|---------|-----------|
| `scripts/setup-qos.sh` | Setup inicial del shaper |
| `scripts/apply-qos-access.sh` | Aplicar QoS en routers de acceso |
| `scripts/qos-monitor.sh` | Monitoreo en tiempo real |
| `scripts/tc-exporter.sh` | Exportador de métricas tc → Prometheus |
| `scripts/test-qos-bandwidth.sh` | Tests de bandwidth |
| `configs/qos/subscriber-plans.conf` | Definición de planes y suscriptores |
| `configs/grafana/dashboards/qos-traffic-shaping.json` | Dashboard Grafana QoS |

---

## Referencias

- [CAKE: Common Applications Kept Enhanced](https://www.bufferbloat.net/projects/codel/wiki/Cake/)
- [tc-htb man page](https://man7.org/linux/man-pages/man8/tc-htb.8.html)
- [fq_codel](https://www.bufferbloat.net/projects/codel/wiki/fq_codel/)
- [Linux Advanced Routing & Traffic Control](https://lartc.org/)
