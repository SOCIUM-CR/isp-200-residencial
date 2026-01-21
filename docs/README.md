# ISP-200 Residencial - Documentación Completa

## Índice

1. [Descripción General](#descripción-general)
2. [Arquitectura de Red](./ARQUITECTURA.md)
3. [Configuración Técnica](./CONFIGURACION-TECNICA.md)
4. [Guía de Operaciones](./OPERACIONES.md)
5. [Monitoreo y Métricas](./MONITOREO.md)

---

## Descripción General

### ¿Qué es este laboratorio?

Este es un laboratorio de simulación de un **ISP (Internet Service Provider) pequeño** diseñado para atender aproximadamente **200 usuarios residenciales** con un único **POP (Point of Presence)**.

### Propósito

- Simular la infraestructura completa de un ISP real
- Practicar configuración de routing (BGP, OSPF)
- Entender el flujo de tráfico desde el cliente hasta Internet
- Experimentar con CGNAT, monitoreo y troubleshooting
- Ambiente seguro para pruebas sin afectar redes de producción

### Stack Tecnológico

| Componente | Tecnología | Versión |
|------------|------------|---------|
| Orquestación | Docker Compose | Latest |
| Routing | FRRouting | 8.4.1 |
| CGNAT | nftables/iptables | Alpine |
| Monitoreo | Prometheus + Grafana | Latest |
| Métricas | cAdvisor | Latest |
| Clientes | network-multitool | Alpine |

### Requisitos del Sistema

- **CPU**: 4+ cores recomendado
- **RAM**: 4+ GB disponible
- **Docker**: Docker Desktop o OrbStack (macOS)
- **Plataforma**: macOS ARM64 (Apple Silicon) / Linux AMD64

---

## Inicio Rápido

```bash
# Clonar/navegar al directorio
cd /Users/francomicalizzi/Downloads/Claude/container-labs-project/labs/isp-200-residencial

# Levantar el laboratorio
docker compose up -d

# Verificar estado
docker compose ps

# Acceder a servicios
# - Grafana: http://localhost:3000 (admin/admin123)
# - Prometheus: http://localhost:9090
```

---

## Estructura del Proyecto

```
labs/isp-200-residencial/
├── docker-compose.yml          # Definición principal del lab
├── docs/                       # Documentación
│   ├── README.md              # Este archivo
│   ├── ARQUITECTURA.md        # Diseño de red
│   ├── CONFIGURACION-TECNICA.md
│   ├── OPERACIONES.md
│   └── MONITOREO.md
├── configs/
│   ├── frr/                   # Configuraciones FRRouting
│   │   ├── upstream-sim/
│   │   ├── edge-router/
│   │   ├── core-router/
│   │   ├── agg-1/
│   │   ├── agg-2/
│   │   ├── acc-1/
│   │   ├── acc-2/
│   │   └── acc-3/
│   ├── cgnat/                 # Configuración NAT
│   ├── pppoe/                 # PPPoE (referencia)
│   ├── radius/                # RADIUS (referencia)
│   └── monitoring/            # Prometheus config
└── scripts/
    ├── traffic-generator.sh   # Generador de tráfico
    └── setup-cgnat.sh         # Setup del router CGNAT
```

---

## Servicios Desplegados

| Servicio | Contenedor | IP | Puerto Externo |
|----------|------------|-----|----------------|
| Upstream (Internet) | isp200-upstream | 192.168.200.1 | - |
| Edge Router | isp200-edge | 192.168.200.2 | - |
| Core Router | isp200-core | 192.168.200.3 | - |
| CGNAT Router | isp200-cgnat | 192.168.200.4 | - |
| Aggregation 1 | isp200-agg1 | 192.168.200.10 | - |
| Aggregation 2 | isp200-agg2 | 192.168.200.11 | - |
| Access 1 | isp200-acc1 | 192.168.200.20 | - |
| Access 2 | isp200-acc2 | 192.168.200.21 | - |
| Access 3 | isp200-acc3 | 192.168.200.22 | - |
| CPE 1-6 | isp200-cpe[1-6] | 192.168.201.x | - |
| Prometheus | isp200-prometheus | 192.168.200.100 | 9090 |
| Grafana | isp200-grafana | 192.168.200.101 | 3000 |
| cAdvisor | isp200-cadvisor | 192.168.200.102 | 9080 |
| Traffic Generator | isp200-traffic-gen | 192.168.200.200 | - |

---

## Autor y Fecha

- **Generado**: Enero 2026
- **Herramienta**: Claude Code (Anthropic)
- **Basado en**: Células de conocimiento del proyecto container-labs
