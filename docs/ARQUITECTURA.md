# Arquitectura de Red - ISP-200 Residencial

## Visión General

Este documento describe la arquitectura de red completa del laboratorio ISP-200, diseñado para simular un proveedor de servicios de Internet pequeño con capacidad para 200 usuarios residenciales.

---

## Diagrama de Topología

```
                            ┌─────────────────────────────────────┐
                            │           INTERNET                  │
                            │         (Simulado)                  │
                            └─────────────────┬───────────────────┘
                                              │
                                              │ BGP eBGP
                                              │ AS 65000
                                              ▼
                            ┌─────────────────────────────────────┐
                            │         UPSTREAM-SIM                │
                            │        192.168.200.1                │
                            │     Simula Transit Provider         │
                            │         Router ID: 10.255.255.1     │
                            └─────────────────┬───────────────────┘
                                              │
                                              │ eBGP Peering
                                              │
                                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              ISP-200 (AS 65100)                             │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         CAPA DE BORDE                                │   │
│  │  ┌─────────────────────────────────────┐                            │   │
│  │  │           EDGE-ROUTER               │                            │   │
│  │  │          192.168.200.2              │                            │   │
│  │  │     Router ID: 10.255.255.10        │                            │   │
│  │  │     BGP AS 65100 + OSPF Area 0      │                            │   │
│  │  └─────────────────┬───────────────────┘                            │   │
│  └────────────────────┼────────────────────────────────────────────────┘   │
│                       │                                                     │
│                       │ OSPF Area 0                                         │
│                       ▼                                                     │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         CAPA CORE                                    │   │
│  │  ┌─────────────────────────────────────┐                            │   │
│  │  │           CORE-ROUTER               │                            │   │
│  │  │          192.168.200.3              │                            │   │
│  │  │     Router ID: 10.255.255.11        │                            │   │
│  │  │          OSPF Backbone              │                            │   │
│  │  └───────┬─────────────────┬───────────┘                            │   │
│  └──────────┼─────────────────┼────────────────────────────────────────┘   │
│             │                 │                                             │
│     ┌───────┘                 └───────┐                                     │
│     │                                 │                                     │
│     ▼                                 ▼                                     │
│  ┌──────────────────┐          ┌──────────────────┐                        │
│  │   CGNAT-ROUTER   │          │   (Futuro BNG)   │                        │
│  │  192.168.200.4   │          │                  │                        │
│  │  NAT 444/CGNAT   │          │                  │                        │
│  └──────────────────┘          └──────────────────┘                        │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      CAPA DE AGREGACIÓN                              │   │
│  │                                                                      │   │
│  │  ┌─────────────────────┐         ┌─────────────────────┐            │   │
│  │  │       AGG-1         │         │       AGG-2         │            │   │
│  │  │   192.168.200.10    │         │   192.168.200.11    │            │   │
│  │  │   Zona Norte        │         │   Zona Sur          │            │   │
│  │  │   (~140 usuarios)   │         │   (~60 usuarios)    │            │   │
│  │  └─────────┬───────────┘         └─────────┬───────────┘            │   │
│  └────────────┼───────────────────────────────┼────────────────────────┘   │
│               │                               │                             │
│       ┌───────┴───────┐                       │                             │
│       │               │                       │                             │
│       ▼               ▼                       ▼                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                       CAPA DE ACCESO                                 │   │
│  │                                                                      │   │
│  │  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐                │   │
│  │  │   ACC-1     │   │   ACC-2     │   │   ACC-3     │                │   │
│  │  │ .200.20     │   │ .200.21     │   │ .200.22     │                │   │
│  │  │ Sector A    │   │ Sector B    │   │ Sector C    │                │   │
│  │  │ ~70 users   │   │ ~70 users   │   │ ~60 users   │                │   │
│  │  └──────┬──────┘   └──────┬──────┘   └──────┬──────┘                │   │
│  └─────────┼─────────────────┼─────────────────┼───────────────────────┘   │
│            │                 │                 │                            │
│            ▼                 ▼                 ▼                            │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         CLIENTES (CPE)                               │   │
│  │                                                                      │   │
│  │  ┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐       │   │
│  │  │ CPE-1 │ │ CPE-2 │ │ CPE-3 │ │ CPE-4 │ │ CPE-5 │ │ CPE-6 │       │   │
│  │  │.201.10│ │.201.20│ │.201.30│ │.201.40│ │.201.50│ │.201.60│       │   │
│  │  └───────┘ └───────┘ └───────┘ └───────┘ └───────┘ └───────┘       │   │
│  │                                                                      │   │
│  │  (Cada CPE representa ~33 usuarios residenciales)                    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

                    SERVICIOS DE INFRAESTRUCTURA
    ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
    │ Prometheus  │  │  Grafana    │  │  cAdvisor   │  │Traffic Gen  │
    │ .200.100    │  │  .200.101   │  │  .200.102   │  │  .200.200   │
    │ :9090       │  │  :3000      │  │  :9080      │  │             │
    └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘
```

---

## Capas de la Red

### 1. Capa de Borde (Edge)

**Función**: Conectar el ISP con el mundo exterior (upstream providers, IXPs, peers).

| Router | Función | Protocolos |
|--------|---------|------------|
| upstream-sim | Simula proveedor de tránsito | BGP AS 65000 |
| edge-router | Router de frontera del ISP | BGP AS 65100 + OSPF |

**Características**:
- Sesión eBGP con el upstream
- Recibe ruta default (0.0.0.0/0)
- Anuncia el bloque del ISP (192.168.192.0/20)
- Redistribuye BGP a OSPF para propagación interna

### 2. Capa Core (Backbone)

**Función**: Backbone de alta velocidad que interconecta todas las capas.

| Router | Función | Protocolos |
|--------|---------|------------|
| core-router | Backbone central | OSPF Area 0 |

**Características**:
- Punto central de routing
- Conecta edge, CGNAT y agregación
- OSPF como IGP principal

### 3. Capa de Agregación

**Función**: Agregar tráfico de múltiples routers de acceso.

| Router | Zona | Usuarios |
|--------|------|----------|
| agg-1 | Norte | ~140 |
| agg-2 | Sur | ~60 |

**Características**:
- Sumarización de rutas hacia el core
- Distribución de tráfico hacia acceso
- OSPF Areas 1 y 2

### 4. Capa de Acceso

**Función**: Terminar conexiones de usuarios finales.

| Router | Sector | Usuarios | Segmentos |
|--------|--------|----------|-----------|
| acc-1 | A | ~70 | 192.168.201.10-19 |
| acc-2 | B | ~70 | 192.168.201.30-39 |
| acc-3 | C | ~60 | 192.168.201.50-59 |

**Características**:
- Interfaces pasivas hacia clientes
- DHCP relay (en producción)
- QoS y traffic shaping (futuro)

---

## Direccionamiento IP

### Esquema General

| Segmento | Red | Máscara | Uso |
|----------|-----|---------|-----|
| Infraestructura | 192.168.200.0 | /24 | Routers, servicios |
| Clientes | 192.168.201.0 | /24 | CPEs simulados |
| Loopbacks | 10.255.255.0 | /24 | Router IDs |
| Red Docker | 192.168.192.0 | /20 | Toda la topología |

### Asignación de Loopbacks (Router IDs)

| Router | Loopback |
|--------|----------|
| upstream-sim | 10.255.255.1 |
| edge-router | 10.255.255.10 |
| core-router | 10.255.255.11 |
| agg-1 | 10.255.255.20 |
| agg-2 | 10.255.255.21 |
| acc-1 | 10.255.255.30 |
| acc-2 | 10.255.255.31 |
| acc-3 | 10.255.255.32 |

---

## Protocolos de Routing

### BGP (Border Gateway Protocol)

```
┌──────────────────┐                    ┌──────────────────┐
│   AS 65000       │                    │   AS 65100       │
│   (Upstream)     │◄──── eBGP ────────►│   (ISP-200)      │
│                  │                    │                  │
│ Anuncia:         │                    │ Anuncia:         │
│ - 0.0.0.0/0      │                    │ - 192.168.192/20 │
└──────────────────┘                    └──────────────────┘
```

**Configuración clave**:
- `no bgp ebgp-requires-policy` (FRR 8.x+)
- Soft-reconfiguration inbound habilitado
- Local-preference para control de tráfico

### OSPF (Open Shortest Path First)

```
                    Area 0 (Backbone)
    ┌─────────────────────────────────────────┐
    │  edge-router ─── core-router            │
    │       │              │                  │
    │       │         ┌────┴────┐             │
    │       │         │         │             │
    │       │      agg-1     agg-2            │
    └───────┼─────────┼─────────┼─────────────┘
            │         │         │
            │    Area 1    Area 2
            │    ┌────┐    ┌────┐
            │    │acc1│    │acc3│
            │    │acc2│    └────┘
            │    └────┘
```

**Áreas OSPF**:
- Area 0: Backbone (edge, core, agg-1, agg-2)
- Area 1: Zona Norte (acc-1, acc-2)
- Area 2: Zona Sur (acc-3)

---

## Flujo de Tráfico

### Tráfico de Usuario hacia Internet

```
CPE (192.168.201.x)
    │
    ▼
ACC Router (Acceso)
    │
    ▼ OSPF
AGG Router (Agregación)
    │
    ▼ OSPF
CORE Router (Backbone)
    │
    ▼ OSPF
EDGE Router (Borde)
    │
    ▼ BGP
UPSTREAM (Internet)
```

### Tráfico de Retorno

```
UPSTREAM (Internet)
    │
    ▼ BGP (ruta hacia 192.168.192.0/20)
EDGE Router
    │
    ▼ OSPF (redistribución BGP)
CORE Router
    │
    ▼ OSPF
AGG Router
    │
    ▼ OSPF
ACC Router
    │
    ▼
CPE (192.168.201.x)
```

---

## Consideraciones de Diseño

### ¿Por qué esta arquitectura?

1. **Escalabilidad**: Capas separadas permiten crecer independientemente
2. **Redundancia**: Fácil agregar redundancia en cada capa
3. **Aislamiento de fallos**: Problemas en acceso no afectan el core
4. **Sumarización**: Reduce tabla de routing en el core

### Diferencias con Producción

| Aspecto | Este Lab | Producción Real |
|---------|----------|-----------------|
| Enlaces | Red Docker bridge | Fibra/Ethernet dedicado |
| Redundancia | Single path | Dual-homed, ECMP |
| BGP | 1 upstream | 2+ upstreams, IXP |
| CGNAT | Simulado | Hardware dedicado |
| CPEs | Contenedores | ONTs, routers físicos |

---

## Próximos Pasos (Evolución)

1. **Agregar redundancia**: Dual edge, dual core
2. **Implementar MPLS**: Para traffic engineering
3. **IPv6 Dual-Stack**: Soporte nativo IPv6
4. **QoS**: Traffic shaping por usuario
5. **BNG completo**: PPPoE con RADIUS real
