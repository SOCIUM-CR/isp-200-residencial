# Monitoreo y Métricas - ISP-200 Residencial

## Índice

1. [Stack de Monitoreo](#stack-de-monitoreo)
2. [Prometheus](#prometheus)
3. [Grafana](#grafana)
4. [cAdvisor](#cadvisor)
5. [Queries Útiles](#queries-útiles)
6. [Alertas](#alertas)

---

## Stack de Monitoreo

### Componentes

| Servicio | Función | Puerto | URL |
|----------|---------|--------|-----|
| Prometheus | Recolección de métricas | 9090 | http://localhost:9090 |
| Grafana | Visualización | 3000 | http://localhost:3000 |
| cAdvisor | Métricas de contenedores | 9080 | http://localhost:9080 |

### Arquitectura

```
┌─────────────────────────────────────────────────────────────────┐
│                      MONITOREO ISP-200                          │
│                                                                 │
│  ┌─────────────┐         ┌─────────────┐         ┌───────────┐ │
│  │  cAdvisor   │────────►│ Prometheus  │────────►│  Grafana  │ │
│  │ (métricas)  │  scrape │  (storage)  │  query  │  (visual) │ │
│  │  :9080      │         │   :9090     │         │   :3000   │ │
│  └─────────────┘         └─────────────┘         └───────────┘ │
│        │                        │                              │
│        ▼                        ▼                              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              CONTENEDORES DEL LAB                        │   │
│  │                                                          │   │
│  │  isp200-edge  isp200-core  isp200-agg1  isp200-acc1 ... │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Prometheus

### Acceso

```
URL: http://localhost:9090
```

### Configuración

Archivo: `configs/monitoring/prometheus.yml`

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['192.168.200.102:8080']
```

### Verificar Targets

1. Ir a http://localhost:9090/targets
2. Verificar que `cadvisor` esté en estado "UP"

### Métricas Disponibles

| Métrica | Descripción |
|---------|-------------|
| `container_network_transmit_bytes_total` | Bytes transmitidos por interfaz |
| `container_network_receive_bytes_total` | Bytes recibidos por interfaz |
| `container_cpu_usage_seconds_total` | Uso de CPU acumulado |
| `container_memory_usage_bytes` | Uso de memoria actual |
| `container_fs_usage_bytes` | Uso de filesystem |

---

## Grafana

### Acceso

```
URL: http://localhost:3000
Usuario: admin
Password: admin123
```

### Datasource

El datasource de Prometheus está preconfigurado:

- **Nombre**: Prometheus
- **URL**: http://192.168.200.100:9090
- **Tipo**: Prometheus

### Verificar Datasource

1. Ir a Configuration → Data Sources
2. Click en "Prometheus"
3. Click "Test" - debe mostrar "Data source is working"

### Dashboard ISP-200

Se incluye un dashboard preconfigurado con:

- **Network Traffic (TX)**: Tráfico de salida por contenedor
- **Network Traffic (RX)**: Tráfico de entrada por contenedor
- **CPU Usage**: Uso de CPU por contenedor
- **Memory Usage**: Uso de memoria por contenedor

### Crear Panel Manualmente

1. Click en "+" → "Dashboard" → "Add new panel"
2. En Query, seleccionar datasource "Prometheus"
3. Ingresar query (ver sección de queries)
4. Ajustar visualización
5. Guardar

---

## cAdvisor

### Acceso

```
URL: http://localhost:9080
```

### Funcionalidad

cAdvisor (Container Advisor) proporciona:

- Métricas de recursos por contenedor
- Uso de CPU, memoria, red, disco
- Estadísticas en tiempo real
- Exportación a Prometheus

### Endpoints Útiles

| Endpoint | Descripción |
|----------|-------------|
| `/` | UI principal |
| `/metrics` | Métricas en formato Prometheus |
| `/api/v1.3/containers` | API de contenedores |

### Nota macOS

En macOS, el endpoint `/docker/` puede mostrar error debido a diferencias en el socket de Docker. Las métricas siguen fluyendo correctamente a Prometheus.

---

## Queries Útiles

### Tráfico de Red

```promql
# Tasa de transmisión (bytes/segundo) - últimos 5 minutos
rate(container_network_transmit_bytes_total[5m])

# Tráfico por contenedor ISP
rate(container_network_transmit_bytes_total{name=~"isp200.*"}[1m])

# Tráfico total transmitido
sum(rate(container_network_transmit_bytes_total[5m]))

# Top 5 contenedores por tráfico
topk(5, rate(container_network_transmit_bytes_total[5m]))
```

### CPU

```promql
# Uso de CPU por contenedor
rate(container_cpu_usage_seconds_total{name=~"isp200.*"}[5m])

# CPU total del lab
sum(rate(container_cpu_usage_seconds_total{name=~"isp200.*"}[5m]))

# Porcentaje de CPU (aproximado)
rate(container_cpu_usage_seconds_total[5m]) * 100
```

### Memoria

```promql
# Memoria usada por contenedor
container_memory_usage_bytes{name=~"isp200.*"}

# Memoria en MB
container_memory_usage_bytes{name=~"isp200.*"} / 1024 / 1024

# Top contenedores por memoria
topk(5, container_memory_usage_bytes)
```

### Contadores de Red

```promql
# Paquetes transmitidos
rate(container_network_transmit_packets_total[5m])

# Errores de red
rate(container_network_transmit_errors_total[5m])

# Paquetes descartados
rate(container_network_transmit_packets_dropped_total[5m])
```

---

## Alertas

### Configurar Alertas en Prometheus

Crear archivo `alerts.yml`:

```yaml
groups:
  - name: isp200_alerts
    rules:
      - alert: ContainerDown
        expr: absent(container_last_seen{name=~"isp200.*"})
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Contenedor ISP200 caído"

      - alert: HighMemoryUsage
        expr: container_memory_usage_bytes{name=~"isp200.*"} > 500000000
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Alto uso de memoria en {{ $labels.name }}"

      - alert: HighNetworkTraffic
        expr: rate(container_network_transmit_bytes_total{name=~"isp200.*"}[5m]) > 10000000
        for: 2m
        labels:
          severity: info
        annotations:
          summary: "Alto tráfico de red en {{ $labels.name }}"
```

### Configurar Alertas en Grafana

1. En un panel, ir a "Alert" tab
2. "Create Alert"
3. Configurar condiciones
4. Configurar notificaciones (email, Slack, etc.)

---

## Troubleshooting de Monitoreo

### Prometheus no muestra datos

```bash
# Verificar que Prometheus está corriendo
docker ps | grep prometheus

# Ver logs
docker logs isp200-prometheus

# Verificar targets
curl http://localhost:9090/api/v1/targets | jq
```

### cAdvisor no reporta métricas

```bash
# Verificar estado
docker ps | grep cadvisor

# Ver logs
docker logs isp200-cadvisor

# Test de métricas
curl http://localhost:9080/metrics | head -50
```

### Grafana no conecta a Prometheus

```bash
# Verificar conectividad interna
docker exec isp200-grafana curl -s http://192.168.200.100:9090/api/v1/status/config

# Verificar datasource via API
curl -u admin:admin123 http://localhost:3000/api/datasources
```

### No hay tráfico visible

```bash
# Verificar que traffic-gen está corriendo
docker ps | grep traffic-gen

# Ver logs del generador
docker logs isp200-traffic-gen

# Generar tráfico manual
docker exec isp200-cpe1 ping -c 10 192.168.200.1
```

---

## Métricas Recomendadas para ISP

### Dashboard Operacional

| Métrica | Query | Propósito |
|---------|-------|-----------|
| Throughput total | `sum(rate(container_network_transmit_bytes_total[5m]))` | Capacidad |
| Uso CPU routers | `rate(container_cpu_usage_seconds_total{name=~"isp200-(edge|core).*"}[5m])` | Salud |
| Memoria routers | `container_memory_usage_bytes{name=~"isp200-(edge|core).*"}` | Recursos |
| Errores de red | `sum(rate(container_network_transmit_errors_total[5m]))` | Calidad |

### KPIs de Red

1. **Disponibilidad**: Porcentaje de tiempo que servicios están UP
2. **Latencia**: Tiempo de respuesta (requiere monitoreo adicional)
3. **Throughput**: Capacidad de transferencia
4. **Errores**: Tasa de paquetes perdidos o errores

---

## Extensiones Futuras

### SNMP Exporter

Para monitorear equipos de red reales:

```yaml
snmp-exporter:
  image: prom/snmp-exporter:latest
  volumes:
    - ./snmp.yml:/etc/snmp_exporter/snmp.yml
  ports:
    - "9116:9116"
```

### Blackbox Exporter

Para monitoreo de endpoints HTTP/ICMP:

```yaml
blackbox-exporter:
  image: prom/blackbox-exporter:latest
  ports:
    - "9115:9115"
```

### gNMIc

Para streaming telemetry (gNMI/gRPC):

```yaml
gnmic:
  image: ghcr.io/openconfig/gnmic:latest
  volumes:
    - ./gnmic.yml:/gnmic.yml
  command: subscribe --config /gnmic.yml
```

