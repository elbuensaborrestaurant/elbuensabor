# API Restaurant — "El Buen Sabor"

Scaffold inicial de la API en Go (Fase 0 del plan de trabajo). Ver el plan completo en
[`../docs/implementation_plan - Creación API Golang.md`](../docs/implementation_plan%20-%20Creaci%C3%B3n%20API%20Golang.md).

## Requisitos

- Go 1.22+
- PostgreSQL 14+ con el esquema `elbuensabor_schema.sql` cargado

## Ejecutar en desarrollo

```bash
cp .env.example .env   # ajustar credenciales de PostgreSQL
go mod tidy
make run
```

## Compilar binario de producción

```bash
make build
./bin/api_restaurant
```

Para el despliegue permanente en el servidor (systemd, firewall, IP fija), ver
[`instalacion_servidor.md`](../docs/instalacion_servidor.md).
