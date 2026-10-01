# Base de Datos PostgreSQL — "El Buen Sabor" / "Sabor Urbano"

Sistema integral de operación local para restaurante, bar y cafetería.

## Módulos cubiertos

Basado en `solicitud.txt`, el esquema cubre los siguientes módulos:

| Módulo | Descripción |
|---|---|
| Establecimiento | Configuración general del negocio |
| Zonas y Mesas | Administración de áreas y mesas con QR |
| Usuarios y Roles | Personal: dueño, gerente, mesero, cocina, barra |
| Menú | Categorías, productos, variantes, personalizaciones |
| Paquetes | Combos / paquetes de productos |
| Órdenes | Pedidos de clientes, ítems, modificadores |
| Cocina / Barra | Pantallas por destino de preparación |
| Solicitudes de Atención | Llamadas a mesero, agua, limpieza, cuenta |
| Inventario | Ingredientes, unidades, movimientos de stock |
| Reservaciones | Gestión de reservaciones por mesa/zona |
| Pagos y Cuentas | Formas de pago, división de cuenta, tickets |
| Reportes (datos) | Tablas que alimentan los reportes de ventas |
| Configuración | Impresoras térmicas, pantallas públicas |

## Entidades principales y relaciones

```
establecimientos
  └─ zonas
       └─ mesas ──── qr_codes
                └─ sesiones_mesa
                       └─ ordenes
                              └─ orden_items
                                     └─ orden_item_modificadores
                              └─ solicitudes_atencion
                              └─ pagos
usuarios ──── roles
productos ─── categorias
           └─ variantes_producto
           └─ modificadores (ej: sin cebolla, extra salsa)
paquetes ─── paquete_items
ingredientes ─── producto_ingredientes
              └─ movimientos_inventario
reservaciones
impresoras_termicas
pantallas_cocina
```

## Decisiones de diseño

- Uso de **UUID** como PK en todas las tablas (portabilidad y privacidad).
- **Timestamps** `created_at` y `updated_at` en todas las tablas con `DEFAULT NOW()`.
- **Soft delete** con columna `deleted_at` en entidades críticas (productos, usuarios, órdenes).
- **ENUM types** para estados de orden, roles, métodos de pago, etc.
- **Esquema `restaurante`** para aislar todo del esquema `public`.
- Índices en columnas de búsqueda frecuente (estado de orden, mesa, fecha).
- Triggers para `updated_at` automático.

## Archivos a generar

#### [NEW] `elbuensabor_schema.sql`
Archivo SQL completo con:
1. Creación del esquema
2. Tipos ENUM
3. Función y trigger para `updated_at`
4. Tablas en orden de dependencia (sin FK circular)
5. Índices
6. Comentarios descriptivos en cada tabla y columna clave

## Open Questions

> [!IMPORTANT]
> Los siguientes puntos pueden afectar el diseño. Si no hay preferencia, se usarán los valores por defecto indicados.

1. **¿Múltiples sucursales?** — El diseño actual soporta UN solo establecimiento. ¿Se requiere soporte multi-sucursal desde el inicio? *(default: una sola sucursal)*
2. **¿Propinas?** — ¿Se debe registrar propina separada del total de pago? *(default: sí, columna opcional)*
3. **¿Facturación electrónica/fiscal?** — ¿Se necesitan campos para RFC, CFDI, datos fiscales? *(default: no incluido en v1)*
4. **¿Comensales identificados?** — ¿Los clientes crean cuenta o son siempre anónimos? *(default: soporte para ambos — cuenta opcional)*
5. **¿Programa de lealtad/puntos?** — *(default: no incluido en v1)*
