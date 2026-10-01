# API REST en Go — "El Buen Sabor" / "Sabor Urbano"

Plan de trabajo para construir, en `API_Restaurant/`, la API que sirve de motor central
local para la PWA de clientes, la PWA de personal, el panel administrativo y las
pantallas KDS, según lo descrito en `solicitud.txt`, `api_manual.md` y el esquema
`elbuensabor_schema.sql`.

## Stack tecnológico

| Capa | Elección | Motivo |
|---|---|---|
| Lenguaje | Go 1.22+ (servidor instalado: 1.25) | Binario único, bajo consumo, ideal para mini PC sin Internet |
| Router HTTP | `net/http` (ServeMux con patrones de método+ruta, stdlib desde Go 1.22) | Cero dependencias externas para enrutamiento |
| Acceso a datos | `pgx/v5` + `pgxpool` | Driver nativo de PostgreSQL, más rápido que `database/sql` genérico |
| Migraciones | `golang-migrate/migrate` | Versionar cambios sobre `elbuensabor_schema.sql` |
| Auth | `golang-jwt/jwt/v5` + `bcrypt` (stdlib `golang.org/x/crypto/bcrypt`) | JWT para personal, hash seguro de contraseñas/PIN |
| Config | Variables de entorno + `godotenv` (solo en dev) | Coincide con `/etc/api_restaurant.env` de `instalacion_servidor.md` |
| Logging | `log/slog` (stdlib) | Structured logging sin dependencias |
| Validación | `go-playground/validator/v10` | Validación declarativa de payloads |
| Testing | stdlib `testing` + `testify/assert` + `httptest` | Pruebas unitarias e integración de handlers |

## Estructura del proyecto

```
API_Restaurant/
├── cmd/
│   └── server/
│       └── main.go                 # entrypoint, arranque y graceful shutdown
├── internal/
│   ├── config/                     # carga y validación de variables de entorno
│   ├── httpserver/                 # router raíz, middlewares globales, envelope de respuestas
│   ├── auth/                       # JWT, hashing, middleware de autenticación y RBAC
│   ├── platform/db/                # pool pgx, health check, transacciones
│   ├── config_mod/                 # dominio "config": establecimiento, zonas, impresoras, KDS
│   ├── personal/                   # usuarios, roles, sesiones
│   ├── menu/                       # categorías, productos, variantes, modificadores, paquetes
│   ├── inventario/                 # ingredientes, recetas, movimientos de stock
│   ├── operaciones/                # mesas, QR, sesiones de mesa, órdenes, items, solicitudes
│   ├── pagos/                      # cuentas, pagos, división de cuenta
│   ├── reservaciones/              # reservaciones
│   ├── lealtad/                    # tarjetas y puntos
│   └── reportes/                   # agregaciones de ventas/inventario para dashboards
├── migrations/                     # elbuensabor_schema.sql versionado con migrate
├── docs/                           # (symlink u referencia a /docs del repo raíz)
├── .env.example
├── Makefile
├── go.mod
└── go.sum
```

Cada módulo de dominio (`menu`, `operaciones`, etc.) sigue la misma organización interna:

```
menu/
├── handler.go     # HTTP handlers, decodifica/valida request, arma respuesta
├── service.go      # reglas de negocio
├── repository.go   # queries SQL con pgx
├── model.go        # structs de dominio y DTOs
└── routes.go        # registro de rutas en el router
```

Esta separación en capas (handler → service → repository) permite probar la lógica de
negocio sin levantar HTTP ni base de datos real (usando fakes del repositorio).

## Convenciones transversales

- **Envelope de respuesta**: todas las respuestas usan el formato de `api_manual.md`
  (`{"success": true/false, "data": ..., "meta": ..., "error": {...}}`), implementado
  una sola vez en `internal/httpserver/response.go`.
- **Errores**: tipo `AppError` con `code` (`NOT_FOUND`, `VALIDATION_ERROR`, etc.) y
  status HTTP asociado, mapeado centralmente por un middleware de recuperación.
- **Autenticación**: middleware que soporta los tres esquemas del manual — JWT Bearer
  (personal), `X-KDS-Token` (pantallas), y rutas públicas sin auth (menú/órdenes vía QR).
- **Autorización (RBAC)**: lectura del campo `permisos JSONB` de `personal.roles` cacheado
  en el JWT (claims) para evitar una consulta extra por request.
- **Paginación**: query params `page` y `per_page`, respondidos en `meta`.
- **Soft delete**: repositorios respetan `deleted_at IS NULL` en `SELECT`/`UPDATE`.
- **UUIDs**: se usa `github.com/google/uuid` para generarlos/parsearlos en Go.
- **Migraciones**: `elbuensabor_schema.sql` se divide en migraciones incrementales
  (`000001_init_schema.up.sql`, etc.) para poder aplicarse con `migrate` en vez de `psql -f`.

## Fases del plan de trabajo

### Fase 0 — Bootstrap del proyecto
- Inicializar `go.mod`, estructura de carpetas, `Makefile`, `.env.example`.
- Conexión a PostgreSQL (`pgxpool`) con health check.
- Endpoint `GET /health` y `GET /api/v1/version`.
- Middleware de logging, recuperación de pánico y CORS (para PWAs servidas en otro puerto).
- Configurar `golang-migrate` apuntando al esquema existente.

### Fase 1 — Auth y Personal
- `POST /auth/login`, `POST /auth/pin`, `POST /auth/logout`, `GET /auth/me`, `POST /auth/refresh`.
- CRUD de `personal.usuarios` y `personal.roles`.
- Middleware JWT + RBAC reutilizable por el resto de módulos.

### Fase 2 — Config
- `establecimiento` (GET/PUT único registro).
- `zonas`, `impresoras_termicas`, `pantallas_cocina` (CRUD + token de acceso KDS).

### Fase 3 — Menú
- `categorias`, `productos`, `variantes_producto`, `grupos_modificadores`,
  `modificadores`, `producto_grupos_modificadores`, `paquetes`, `paquete_items`.
- Endpoint público de menú para la PWA cliente (sin auth), filtrando `estado`/`disponible`.

### Fase 4 — Operaciones (núcleo del sistema)
- `mesas`, `qr_codes` (resolución pública por token).
- `sesiones_mesa` (abrir/cerrar sesión de mesa).
- `ordenes`, `orden_items`, `orden_item_modificadores` (creación desde QR y desde personal).
- `solicitudes_atencion` (llamar mesero, agua, cuenta, etc.).
- Notificación en tiempo real a cocina/barra: WebSocket o Server-Sent Events sobre
  `internal/httpserver` para refrescar KDS y apps de personal sin polling agresivo.

### Fase 5 — Pagos
- `cuentas` (cálculo de subtotal/impuestos/total desde `ordenes`).
- `pagos`, `pago_items` (división de cuenta), registro de propina.

### Fase 6 — Inventario
- `unidades_medida`, `ingredientes`, `producto_ingredientes` (recetas).
- `movimientos_inventario`: descuento automático de stock al confirmar `orden_items`,
  alertas de `stock_actual <= stock_minimo`.

### Fase 7 — Reservaciones y Lealtad
- CRUD de `reservaciones` con generación de `codigo`.
- `tarjetas`, `reglas_puntos`, `movimientos_puntos`: acumulación automática al pagar.

### Fase 8 — Reportes
- Endpoints agregados de ventas (día/semana/mes), productos más vendidos, ocupación de mesas.
- Uso de vistas SQL o queries agregadas directamente (sin ORM).

### Fase 9 — Endurecimiento y despliegue
- Pruebas de integración con base de datos de prueba (contenedor o schema `test`).
- Rate limiting básico en endpoints públicos (QR) para mitigar abuso desde la LAN.
- Build multiplataforma (`amd64`/`arm64`) y validación del binario según
  `instalacion_servidor.md`.
- Registro como servicio `systemd` y checklist de verificación final.

## Mapeo módulo → esquema de base de datos

| Módulo Go | Esquema Postgres |
|---|---|
| `auth`, `personal` | `personal` |
| `config_mod` | `config` |
| `menu` | `menu` |
| `inventario` | `inventario` |
| `operaciones` | `operaciones` |
| `pagos` | `pagos` |
| `reservaciones` | `reservaciones` |
| `lealtad` | `lealtad` |
| `reportes` | consultas cruzadas sobre varios esquemas |

## Archivos a generar (scaffold inicial)

#### [NEW] `go.mod`
Módulo Go con dependencias iniciales (`pgx/v5`, `jwt/v5`, `godotenv`, `uuid`).

#### [NEW] `cmd/server/main.go`
Entrypoint: carga config, conecta a DB, registra rutas, arranca servidor HTTP con
apagado ordenado (`context` + `signal.NotifyContext`).

#### [NEW] `internal/config/config.go`
Carga de variables de entorno (`DB_*`, `SERVER_*`, `JWT_*`) con valores por defecto.

#### [NEW] `internal/platform/db/db.go`
Creación del `pgxpool.Pool` y función `Ping`.

#### [NEW] `internal/httpserver/response.go`
Helpers `WriteSuccess`, `WriteError`, `WritePaginated` con el envelope estándar.

#### [NEW] `.env.example`, `Makefile`, `README.md`
Plantillas de configuración y comandos de desarrollo (`make run`, `make build`, `make test`).

## Instrucciones para ejecutar la API en este servidor

### A. Modo desarrollo (con Go instalado localmente)

```bash
cd /home/evazquez/Desarrollo/elbuensabor/API_Restaurant

# 1. Copiar variables de entorno de ejemplo
cp .env.example .env
# Editar .env con los datos reales de PostgreSQL

# 2. Descargar dependencias
go mod download

# 3. Levantar PostgreSQL local (si no está corriendo) y cargar el esquema
sudo systemctl start postgresql
psql -U api_user -d elbuensabor -f ../docs/elbuensabor_schema.sql

# 4. Ejecutar la API en caliente
go run ./cmd/server
```

La API quedará disponible en `http://localhost:8080/api/v1` (ver `api_manual.md`).

### B. Compilar el binario de producción

```bash
cd /home/evazquez/Desarrollo/elbuensabor/API_Restaurant
CGO_ENABLED=0 GOOS=linux go build -o bin/api_restaurant ./cmd/server
./bin/api_restaurant   # requiere variables de entorno cargadas (.env o systemd EnvironmentFile)
```

### C. Despliegue permanente en este servidor (systemd)

Seguir la guía completa ya documentada en
[instalacion_servidor.md](instalacion_servidor.md), secciones 5 a 9:

1. Instalar Go (sección 5) — **ya presente en este equipo** (`go version` → `go1.25.10`).
2. Compilar el binario y copiarlo a `/opt/api_restaurant` (sección 6).
3. Crear `/etc/api_restaurant.env` con las variables reales (sección 7).
4. Registrar y habilitar el servicio `api_restaurant.service` (sección 8).
5. Abrir el puerto 8080 en el firewall local (sección 9).

Comandos rápidos de verificación una vez desplegado:

```bash
sudo systemctl status api_restaurant
curl http://localhost:8080/health
curl http://localhost:8080/api/v1/menu/categorias
journalctl -u api_restaurant -f
```

## Open Questions

> [!IMPORTANT]
> Estos puntos afectan decisiones de arquitectura. Se usará el valor por defecto si no
> hay preferencia indicada.

1. **¿Framework HTTP o stdlib?** — Se propone `net/http` puro (Go 1.22+ ya soporta
   patrones `METHOD /ruta/{id}`). *(default: stdlib, sin Gin/Echo/Fiber)*
2. **¿Tiempo real para KDS/mesero?** — ¿WebSocket, SSE o polling corto? *(default: SSE,
   más simple de operar detrás del firewall local que WebSocket)*
3. **¿Multi-tenant / múltiples sucursales?** — El esquema asume un solo establecimiento.
   *(default: no, una sola instancia por restaurante)*
4. **¿Contenedores (Docker) o binario nativo?** — `instalacion_servidor.md` asume binario
   nativo + systemd. *(default: binario nativo, sin Docker, para minimizar overhead en
   hardware económico)*
5. **¿Entorno de pruebas de integración?** — ¿Base de datos de prueba dedicada o schema
   `test` en la misma instancia? *(default: base de datos separada `elbuensabor_test`)*
