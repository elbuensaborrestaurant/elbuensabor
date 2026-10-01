# Manual de Uso — API REST "El Buen Sabor"

> Version 1.0.0 | Motor: Go | Base de datos: PostgreSQL
> Ultima actualizacion: 2026-09-18

---

## Tabla de Contenido

1. Introduccion
2. Base URL y acceso
3. Autenticacion
4. Formato de respuestas
5. Modulo: Auth
6. Modulo: Config
7. Modulo: Personal
8. Modulo: Menu
9. Modulo: Operaciones
10. Modulo: Pagos
11. Modulo: Inventario
12. Modulo: Reservaciones
13. Modulo: Lealtad
14. Modulo: Reportes
15. Flujos operativos
16. Codigos de error

---

## 1. Introduccion

La API REST de **El Buen Sabor** es el motor central del sistema de restaurante. Provee todos los servicios necesarios para:

- La **PWA del cliente** (menu, ordenes via QR, solicitudes de atencion)
- La **PWA del personal** (meseros, cocina, barra, caja)
- El **Panel Administrativo** (gerente y dueno)
- Las **Pantallas KDS** (Kitchen Display System)

La API opera 100% en red local (LAN/WiFi). No requiere Internet externo para funcionar.

---

## 2. Base URL y Acceso

```
http://<IP-DEL-SERVIDOR>:8080/api/v1
```

**Ejemplos:**
- En desarrollo: `http://localhost:8080/api/v1`
- En produccion local: `http://192.168.1.100:8080/api/v1`

---

## 3. Autenticacion

La API utiliza tres mecanismos segun el tipo de cliente:

### 3.1 JWT — Personal del restaurante

```
Authorization: Bearer <jwt_token>
```

Obtener un JWT:
```http
POST /api/v1/auth/login
Content-Type: application/json

{
  "username": "luis.gerente",
  "password": "mi_contrasena"
}
```

Respuesta:
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "expires_at": "2026-09-19T01:00:00Z",
    "usuario": {
      "id": "550e8400-...",
      "nombre": "Luis",
      "rol": "gerente"
    }
  }
}
```

### 3.2 Token KDS — Pantallas de cocina/barra

```
X-KDS-Token: <uuid_token_acceso>
```

El UUID se genera al registrar la pantalla en `POST /api/v1/config/pantallas-cocina`.

### 3.3 Acceso publico — Clientes QR

Los endpoints del menu y creacion de ordenes desde QR no requieren autenticacion.
El token del QR (UUID de la mesa) se pasa como query param o en la ruta:

```
GET /api/v1/operaciones/qr/3f2a7b91-...
```

---

## 4. Formato de Respuestas

### Respuesta exitosa
```json
{
  "success": true,
  "data": { ... },
  "meta": {
    "page": 1,
    "per_page": 20,
    "total": 150
  }
}
```

`meta` solo aparece en listados paginados.

### Respuesta de error
```json
{
  "success": false,
  "error": {
    "code": "NOT_FOUND",
    "message": "El recurso solicitado no existe."
  }
}
```

### Codigos HTTP utilizados

| Codigo | Significado |
|---|---|
| 200 | OK - Operacion exitosa |
| 201 | Created - Recurso creado |
| 204 | No Content - Eliminacion exitosa |
| 400 | Bad Request - Payload invalido |
| 401 | Unauthorized - Token ausente o invalido |
| 403 | Forbidden - Sin permisos suficientes |
| 404 | Not Found - Recurso no existe |
| 409 | Conflict - Conflicto de datos (duplicado) |
| 422 | Unprocessable Entity - Validacion fallida |
| 500 | Internal Server Error - Error del servidor |

---

## 5. Modulo: Auth

### POST /auth/login
Login con usuario y contrasena.

**Body:**
```json
{
  "username": "string (requerido)",
  "password": "string (requerido)"
}
```

**Respuesta 200:**
```json
{
  "success": true,
  "data": {
    "token": "eyJ...",
    "expires_at": "2026-09-19T02:00:00Z",
    "usuario": {
      "id": "uuid",
      "nombre": "Maria",
      "apellido": "Lopez",
      "rol": "mesero",
      "tipo_rol": "mesero"
    }
  }
}
```

---

### POST /auth/pin
Login rapido desde tablet con PIN de 6 digitos.

**Body:**
```json
{
  "username": "maria.lopez",
  "pin": "123456"
}
```

El JWT emitido tiene expiracion corta (2h por defecto).

---

### POST /auth/logout
Invalida el token actual.

**Header:** `Authorization: Bearer <token>`

**Respuesta:** 204 No Content

---

### GET /auth/me
Retorna datos del usuario autenticado.

**Respuesta 200:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "nombre": "Luis",
    "apellido": "Garcia",
    "email": "luis@example.com",
    "username": "luis.dueno",
    "foto_url": null,
    "rol": {
      "id": "uuid",
      "nombre": "Dueno / Director General",
      "tipo": "dueno"
    },
    "ultimo_login": "2026-09-18T14:00:00Z"
  }
}
```

---

### POST /auth/refresh
Renueva el JWT antes de que expire.

**Header:** `Authorization: Bearer <token>`

**Respuesta 200:** Mismo formato que `/auth/login`

---

## 6. Modulo: Config

### GET /config/establecimiento
Obtiene la configuracion del restaurante.

```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "nombre": "Sabor Urbano",
    "slogan": "La mejor experiencia gastronomica",
    "direccion": "Av. Principal 123, Col. Centro",
    "telefono": "555-0001",
    "wifi_ssid": "SaborUrbano_Local",
    "timezone": "America/Mexico_City",
    "moneda": "MXN",
    "porcentaje_iva": 16.00,
    "mensaje_ticket": "Gracias por visitarnos!"
  }
}
```

---

### PUT /config/establecimiento
Actualiza configuracion del restaurante.

**Roles permitidos:** dueno, gerente

**Body (campos opcionales):**
```json
{
  "nombre": "string",
  "slogan": "string",
  "direccion": "string",
  "telefono": "string",
  "wifi_ssid": "string",
  "porcentaje_iva": 16.00,
  "mensaje_ticket": "string"
}
```

---

### GET /config/zonas
Lista zonas del restaurante.

**Query params:**
- `estado` — `activo` | `inactivo` (default: `activo`)

**Respuesta:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "nombre": "Salon Principal",
      "descripcion": "Area principal del restaurante",
      "color_hex": "#4F46E5",
      "icono": "sofa",
      "orden": 1,
      "estado": "activo"
    }
  ]
}
```

---

### POST /config/zonas

**Body:**
```json
{
  "nombre": "Terraza VIP",
  "descripcion": "Area de terraza exclusiva",
  "color_hex": "#10B981",
  "icono": "star",
  "orden": 5
}
```

---

### POST /config/impresoras
Registra una impresora termica.

**Body:**
```json
{
  "nombre": "Impresora Cocina",
  "modelo": "Epson TM-T20III",
  "ip_address": "192.168.1.201",
  "puerto": 9100,
  "destino": "cocina",
  "es_ticket": false
}
```

El campo `destino` acepta: `cocina`, `barra`, `mostrador`

---

### POST /config/pantallas-cocina
Registra una pantalla KDS.

**Body:**
```json
{
  "nombre": "Pantalla Cocina Principal",
  "destino": "cocina",
  "ip_address": "192.168.1.210"
}
```

**Respuesta 201:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "nombre": "Pantalla Cocina Principal",
    "destino": "cocina",
    "token_acceso": "a1b2c3d4-...",
    "estado": "activo"
  }
}
```

El `token_acceso` es el UUID que debe configurarse en la pantalla KDS como header `X-KDS-Token`.

---

## 7. Modulo: Personal

### GET /personal/usuarios
Lista todos los usuarios del personal.

**Roles permitidos:** gerente, dueno

**Query params:**
- `rol_id` — Filtrar por rol
- `estado` — `activo` | `inactivo`

---

### POST /personal/usuarios
Crea un nuevo usuario.

**Body:**
```json
{
  "rol_id": "uuid",
  "nombre": "Ana",
  "apellido": "Martinez",
  "email": "ana@sabor.local",
  "username": "ana.mesero",
  "password": "contrasena_segura",
  "pin": "456789"
}
```

El PIN se almacena hasheado. Usar 6 digitos numericos.

---

### PATCH /personal/usuarios/:id/estado
Activa o desactiva al usuario.

**Body:**
```json
{ "estado": "inactivo" }
```

---

### PUT /personal/usuarios/:id/password
Cambia la contrasena.

**Body:**
```json
{
  "password_actual": "vieja_clave",
  "password_nuevo": "nueva_clave_segura"
}
```

---

### GET /personal/roles
Lista todos los roles disponibles.

**Respuesta:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "nombre": "Mesero",
      "tipo": "mesero",
      "descripcion": "Toma de ordenes y atencion a mesas.",
      "permisos": {
        "ordenes": {"ver": true, "crear": true, "editar": true},
        "mesas": {"ver": true}
      }
    }
  ]
}
```

---

## 8. Modulo: Menu

Todos los endpoints GET de este modulo son PUBLICOS (sin JWT). Son accesibles desde la PWA del cliente conectado a la LAN del restaurante.

### GET /menu/categorias
Lista categorias activas del menu.

**Respuesta:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "nombre": "Entradas",
      "descripcion": "Para abrir el apetito",
      "imagen_url": "http://192.168.1.100:8080/images/entradas.jpg",
      "color_hex": "#F59E0B",
      "icono": "utensils",
      "orden": 1
    }
  ]
}
```

---

### GET /menu/productos
Lista productos del menu.

**Query params:**
- `categoria_id` — Filtrar por categoria
- `destino` — `cocina` | `barra` | `mostrador`
- `disponible` — `true` | `false`
- `page` — Numero de pagina (default: 1)
- `per_page` — Resultados por pagina (default: 20)

---

### GET /menu/productos/:id
Obtiene detalle completo de un producto incluyendo variantes y grupos de modificadores.

**Respuesta:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "nombre": "Arrachera a la Plancha",
    "descripcion": "350g de arrachera marinada...",
    "imagen_url": "...",
    "precio": 185.00,
    "tiempo_prep_min": 18,
    "destino": "cocina",
    "es_vegano": false,
    "es_sin_gluten": true,
    "calorias": 520,
    "disponible": true,
    "variantes": [
      {"id": "uuid", "nombre": "200g", "precio_extra": -30.00}
    ],
    "grupos_modificadores": [
      {
        "id": "uuid",
        "nombre": "Termino de coccion",
        "obligatorio": true,
        "seleccion_maxima": 1,
        "modificadores": [
          {"id": "uuid", "nombre": "Rojo", "precio_extra": 0.00},
          {"id": "uuid", "nombre": "Medio", "precio_extra": 0.00},
          {"id": "uuid", "nombre": "Bien cocido", "precio_extra": 0.00}
        ]
      }
    ]
  }
}
```

---

### POST /menu/productos
Crea un producto.

**Body:**
```json
{
  "categoria_id": "uuid",
  "nombre": "Ensalada Cesar",
  "descripcion": "Lechuga, crutones, queso parmesano y aderezo.",
  "precio": 95.00,
  "precio_costo": 35.00,
  "tiempo_prep_min": 5,
  "destino": "cocina",
  "es_vegetariano": true,
  "orden": 3
}
```

---

### PATCH /menu/productos/:id/disponibilidad
Activa o desactiva un producto rapidamente (cuando se acaba un platillo).

**Body:**
```json
{ "disponible": false }
```

---

### GET /menu/paquetes
Lista combos/paquetes disponibles.

**Respuesta:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "nombre": "Combo Familiar",
      "descripcion": "4 tacos + 4 bebidas a precio especial",
      "precio": 280.00,
      "disponible": true,
      "items": [
        {"nombre_item": "Taco de arrachera", "cantidad": 4},
        {"nombre_item": "Agua de sabor", "cantidad": 4}
      ]
    }
  ]
}
```

---

## 9. Modulo: Operaciones

### GET /operaciones/mesas
Lista todas las mesas con su estado actual.

**Respuesta:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "zona": {"id": "uuid", "nombre": "Salon Principal"},
      "numero": "5",
      "nombre": "Mesa junto a la ventana",
      "capacidad": 4,
      "estado": "disponible"
    }
  ]
}
```

Estados posibles: `disponible`, `ocupada`, `reservada`, `en_limpieza`, `fuera_de_servicio`

---

### PATCH /operaciones/mesas/:id/estado

**Body:**
```json
{ "estado": "en_limpieza" }
```

---

### GET /operaciones/qr/:token
Resuelve un token QR para identificar la mesa. Se usa cuando el cliente escanea el QR.

**Respuesta:**
```json
{
  "success": true,
  "data": {
    "mesa_id": "uuid",
    "mesa_numero": "5",
    "zona": "Salon Principal",
    "sesion_activa_id": "uuid"
  }
}
```

---

### POST /operaciones/sesiones
Abre una sesion en una mesa.

**Body:**
```json
{
  "mesa_id": "uuid",
  "num_comensales": 3,
  "notas_internas": "Cliente con ninos"
}
```

**Respuesta 201:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "mesa_id": "uuid",
    "mesa_numero": "5",
    "estado": "activa",
    "num_comensales": 3,
    "iniciada_en": "2026-09-18T20:30:00Z"
  }
}
```

---

### POST /operaciones/ordenes
Crea una nueva orden. Puede ser iniciada por un mesero (JWT) o por el cliente (sin JWT, sesion por QR).

**Body:**
```json
{
  "sesion_id": "uuid",
  "notas": "Sin cilantro en todo",
  "items": [
    {
      "producto_id": "uuid",
      "cantidad": 2,
      "notas_especiales": "Extra salsa",
      "modificadores": [
        {
          "modificador_id": "uuid",
          "nombre_snapshot": "Bien cocido",
          "precio_extra": 0.00
        }
      ]
    }
  ]
}
```

**Respuesta 201:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "numero_orden": 42,
    "sesion_id": "uuid",
    "estado": "confirmada",
    "items": [...]
  }
}
```

---

### GET /operaciones/cocina/comandas
Retorna todos los items pendientes o en preparacion destinados a cocina.

**Header:** `X-KDS-Token: <token_pantalla>`

**Respuesta:**
```json
{
  "success": true,
  "data": [
    {
      "orden_id": "uuid",
      "numero_orden": 42,
      "mesa": "5",
      "zona": "Salon Principal",
      "tiempo_espera_min": 8,
      "items": [
        {
          "id": "uuid",
          "producto": "Arrachera a la Plancha",
          "cantidad": 2,
          "estado": "en_preparacion",
          "notas_especiales": "Extra salsa",
          "modificadores": ["Bien cocido"],
          "enviado_en": "2026-09-18T20:35:00Z"
        }
      ]
    }
  ]
}
```

---

### PATCH /operaciones/items/:id/estado
Actualiza el estado de un item desde la pantalla KDS.

**Header:** `X-KDS-Token: <token_pantalla>` (o JWT)

**Body:**
```json
{ "estado": "listo" }
```

Estados validos: `pendiente`, `en_preparacion`, `listo`, `entregado`, `cancelado`

---

### POST /operaciones/solicitudes
El cliente solicita atencion desde su celular (sin autenticacion).

**Body:**
```json
{
  "sesion_id": "uuid",
  "tipo": "agua",
  "descripcion": "Necesitamos 2 vasos de agua con hielo"
}
```

Tipos validos: `llamar_mesero`, `agua`, `servilletas`, `limpieza`, `cuenta`, `otro`

---

### PATCH /operaciones/solicitudes/:id/atender

**Body:**
```json
{ "estado": "atendida" }
```

---

### PATCH /operaciones/sesiones/:id/cerrar
Cierra la sesion de mesa al finalizar la visita.

**Body:**
```json
{ "notas_cierre": "Cliente satisfecho" }
```

---

## 10. Modulo: Pagos

### POST /pagos/cuentas
Genera la cuenta para una sesion. Calcula subtotal, IVA y total automaticamente.

**Body:**
```json
{ "sesion_id": "uuid" }
```

**Respuesta 201:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "sesion_id": "uuid",
    "subtotal": 340.00,
    "descuento": 0.00,
    "impuestos": 54.40,
    "total": 394.40,
    "estado": "pendiente",
    "dividida_en": 1
  }
}
```

---

### PATCH /pagos/cuentas/:id/dividir
Divide la cuenta en N partes iguales.

**Body:**
```json
{ "dividida_en": 3 }
```

---

### POST /pagos/cuentas/:id/pagar
Registra un pago sobre la cuenta.

**Body:**
```json
{
  "metodo": "efectivo",
  "monto": 200.00,
  "propina": 30.00,
  "cambio": 5.60
}
```

Metodos validos: `efectivo`, `tarjeta_credito`, `tarjeta_debito`, `transferencia`, `qr_pago`, `puntos_lealtad`, `otro`

---

## 11. Modulo: Inventario

### GET /inventario/ingredientes
Lista todos los ingredientes con su stock.

**Query params:**
- `estado` — `activo` | `inactivo`
- `stock_bajo` — `true` (solo ingredientes bajo el minimo)

---

### POST /inventario/ingredientes/:id/movimiento
Registra una entrada, salida o ajuste de inventario.

**Body:**
```json
{
  "tipo": "entrada",
  "cantidad": 5.000,
  "costo_unitario": 45.00,
  "notas": "Compra semanal al proveedor ABC"
}
```

Tipos validos: `entrada`, `salida`, `ajuste`, `merma`, `produccion`

---

### GET /inventario/alertas-stock
Retorna ingredientes cuyo stock actual esta por debajo del minimo configurado.

**Respuesta:**
```json
{
  "success": true,
  "data": [
    {
      "nombre": "Arrachera",
      "unidad": "kg",
      "stock_actual": 1.500,
      "stock_minimo": 3.000,
      "faltante": 1.500,
      "proveedor": "Carnes del Norte SA"
    }
  ]
}
```

---

## 12. Modulo: Reservaciones

### GET /reservaciones
Lista reservaciones.

**Query params:**
- `fecha_desde` — Formato ISO 8601: `2026-09-19`
- `fecha_hasta` — Formato ISO 8601: `2026-09-20`
- `estado` — `pendiente` | `confirmada` | `cancelada` | `completada`

---

### POST /reservaciones
Crea una reservacion. Disponible sin JWT para reservaciones online del cliente.

**Body:**
```json
{
  "nombre_contacto": "Carlos Perez",
  "telefono": "55-1234-5678",
  "email": "carlos@email.com",
  "num_personas": 4,
  "fecha_hora": "2026-09-19T20:00:00-06:00",
  "duracion_min": 90,
  "notas": "Festejo de cumpleanos",
  "mesa_id": "uuid"
}
```

**Respuesta 201:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "codigo": "RES-0043",
    "nombre_contacto": "Carlos Perez",
    "fecha_hora": "2026-09-19T20:00:00-06:00",
    "estado": "pendiente"
  }
}
```

---

### GET /reservaciones/codigo/:codigo
Consulta estado de una reservacion por su codigo de confirmacion. Disponible sin JWT.

```
GET /api/v1/reservaciones/codigo/RES-0043
```

---

### PATCH /reservaciones/:id/estado
Actualiza el estado de la reservacion.

**Body:**
```json
{ "estado": "confirmada" }
```

Estados validos: `pendiente`, `confirmada`, `cancelada`, `no_presentado`, `completada`

---

## 13. Modulo: Lealtad

### GET /lealtad/tarjetas/:numero
Consulta el saldo de puntos de una tarjeta por su numero o telefono.

```
GET /api/v1/lealtad/tarjetas/5512345678
```

**Respuesta:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "numero": "5512345678",
    "alias": "Cliente frecuente",
    "puntos_acumulados": 450,
    "puntos_canjeados": 100,
    "puntos_disponibles": 350
  }
}
```

---

### POST /lealtad/tarjetas/:id/acumular
Acumula puntos al cerrar una cuenta pagada.

**Body:**
```json
{
  "pago_id": "uuid",
  "regla_id": "uuid",
  "descripcion": "Compra del 18/09/2026"
}
```

---

### POST /lealtad/tarjetas/:id/canjear
Canjea puntos de una tarjeta.

**Body:**
```json
{
  "puntos": 100,
  "pago_id": "uuid",
  "descripcion": "Canje en cuenta"
}
```

---

## 14. Modulo: Reportes

### GET /reportes/ventas/hoy
Ventas del dia agrupadas por hora.

**Respuesta:**
```json
{
  "success": true,
  "data": [
    {
      "hora": "2026-09-18T12:00:00Z",
      "num_transacciones": 8,
      "total_ventas": 1240.00,
      "total_propinas": 180.00,
      "total_con_propina": 1420.00
    }
  ]
}
```

---

### GET /reportes/ventas/rango
Ventas en un rango de fechas.

**Query params:**
- `desde` — `2026-09-01`
- `hasta` — `2026-09-18`
- `agrupar_por` — `dia` | `semana` | `mes`

---

### GET /reportes/mesas-activas
Mesas actualmente en servicio con tiempo transcurrido.

---

### GET /reportes/productos-mas-vendidos
Top 20 productos mas vendidos en unidades.

---

## 15. Flujos Operativos

### Flujo 1: Llegada del cliente y apertura de mesa

```
1. Mesero (JWT)  → PATCH /operaciones/mesas/:id/estado    { estado: "ocupada" }
2. Mesero (JWT)  → POST  /operaciones/sesiones             { mesa_id, num_comensales }
3. Cliente       → Escanea QR de la mesa
4. Sistema       → GET   /operaciones/qr/:token            (identifica mesa)
5. Cliente       → GET   /menu/categorias + /menu/productos
```

---

### Flujo 2: Cliente ordena desde su celular

```
1. Cliente       → POST  /operaciones/ordenes              { sesion_id, items:[...] }
2. KDS Cocina    → GET   /operaciones/cocina/comandas      (aparece la orden)
3. Cocinero      → PATCH /operaciones/items/:id/estado     { estado: "en_preparacion" }
4. Cocinero      → PATCH /operaciones/items/:id/estado     { estado: "listo" }
5. Mesero (JWT)  → PATCH /operaciones/items/:id/estado     { estado: "entregado" }
```

---

### Flujo 3: Pago y cierre de mesa

```
1. Cliente       → POST  /operaciones/solicitudes          { tipo: "cuenta", sesion_id }
2. Caja (JWT)    → POST  /pagos/cuentas                    { sesion_id }
3. Caja (JWT)    → POST  /pagos/cuentas/:id/pagar          { metodo, monto, propina }
4. Caja (JWT)    → PATCH /operaciones/sesiones/:id/cerrar
5. Sistema       → PATCH /operaciones/mesas/:id/estado     { estado: "en_limpieza" }
```

---

### Flujo 4: Solicitud de atencion del cliente

```
1. Cliente       → POST  /operaciones/solicitudes          { tipo: "servilletas", sesion_id }
2. Mesero (JWT)  → GET   /operaciones/solicitudes?estado=pendiente
3. Mesero (JWT)  → PATCH /operaciones/solicitudes/:id/atender
```

---

## 16. Codigos de Error

| Codigo | Descripcion |
|---|---|
| `INVALID_CREDENTIALS` | Usuario o contrasena incorrectos |
| `UNAUTHORIZED` | Token ausente, invalido o expirado |
| `FORBIDDEN` | El rol del usuario no tiene permisos para esta accion |
| `NOT_FOUND` | El recurso solicitado no existe |
| `VALIDATION_ERROR` | Uno o mas campos no pasan la validacion |
| `CONFLICT` | Duplicado: el recurso ya existe |
| `MESA_OCUPADA` | La mesa ya tiene una sesion activa |
| `STOCK_INSUFICIENTE` | No hay stock suficiente del ingrediente |
| `CUENTA_YA_PAGADA` | La cuenta ya fue saldada |
| `INTERNAL_ERROR` | Error interno del servidor (revisar logs) |

---

## Apendice: Tipos ENUM Validos

| ENUM | Valores |
|---|---|
| `tipo_rol` | `dueno`, `gerente`, `mesero`, `cocina`, `barra`, `caja` |
| `estado_mesa` | `disponible`, `ocupada`, `reservada`, `en_limpieza`, `fuera_de_servicio` |
| `estado_sesion` | `activa`, `cerrada`, `cancelada` |
| `estado_orden` | `borrador`, `confirmada`, `en_preparacion`, `lista`, `entregada`, `cancelada` |
| `estado_item` | `pendiente`, `en_preparacion`, `listo`, `entregado`, `cancelado` |
| `tipo_solicitud` | `llamar_mesero`, `agua`, `servilletas`, `limpieza`, `cuenta`, `otro` |
| `destino_preparacion` | `cocina`, `barra`, `mostrador` |
| `metodo_pago` | `efectivo`, `tarjeta_credito`, `tarjeta_debito`, `transferencia`, `qr_pago`, `puntos_lealtad`, `otro` |
| `estado_pago` | `pendiente`, `pagado`, `reembolsado`, `fallido` |
| `tipo_movimiento_inv` | `entrada`, `salida`, `ajuste`, `merma`, `produccion` |
| `estado_reservacion` | `pendiente`, `confirmada`, `cancelada`, `no_presentado`, `completada` |
| `tipo_movimiento_puntos` | `acumulacion`, `canje`, `ajuste`, `vencimiento` |
