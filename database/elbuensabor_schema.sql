-- ============================================================
-- EL BUEN SABOR — Base de Datos PostgreSQL
-- Sistema integral de operación local para restaurante,
-- bar y cafetería "Sabor Urbano"
--
-- Motor:    PostgreSQL 14+
-- Versión:  1.0.0
-- Generado: 2026-09-18
--
-- ESQUEMAS:
--   config        → Configuración del establecimiento, zonas,
--                   impresoras y pantallas KDS
--   menu          → Catálogo de categorías, productos, variantes,
--                   modificadores y paquetes/combos
--   personal      → Usuarios, roles y sesiones del personal
--   operaciones   → Mesas, QR, sesiones, órdenes, items,
--                   solicitudes de atención
--   pagos         → Cuentas, transacciones, propinas y
--                   estructura preparada para CFDI
--   inventario    → Ingredientes, recetas y movimientos de stock
--   reservaciones → Gestión de reservaciones de mesas
--   lealtad       → Programa de puntos con tarjetas anónimas
--
-- USO:
--   psql -U <usuario> -d <base_de_datos> -f elbuensabor_schema.sql
-- ============================================================


-- ============================================================
-- 0. COMPATIBILIDAD Y GENERACIÓN DE UUID
-- ============================================================
-- PostgreSQL 13+ incluye gen_random_uuid() de forma nativa en el core.
-- No se requieren extensiones externas (uuid-ossp o pgcrypto).


-- ============================================================
-- 1. ESQUEMAS
-- ============================================================
\encoding UTF8
CREATE SCHEMA IF NOT EXISTS config;
COMMENT ON SCHEMA config IS 'Configuración global del establecimiento: zonas, impresoras y pantallas KDS.';

CREATE SCHEMA IF NOT EXISTS menu;
COMMENT ON SCHEMA menu IS 'Catálogo del menú: categorías, productos, variantes, modificadores y paquetes.';

CREATE SCHEMA IF NOT EXISTS personal;
COMMENT ON SCHEMA personal IS 'Gestión del personal: usuarios, roles y sesiones de acceso.';

CREATE SCHEMA IF NOT EXISTS operaciones;
COMMENT ON SCHEMA operaciones IS 'Flujo operativo: mesas, QR, sesiones, órdenes, items y solicitudes de atención.';

CREATE SCHEMA IF NOT EXISTS pagos;
COMMENT ON SCHEMA pagos IS 'Cuentas, transacciones de pago, propinas y estructura lista para CFDI.';

CREATE SCHEMA IF NOT EXISTS inventario;
COMMENT ON SCHEMA inventario IS 'Ingredientes, recetas de productos y auditoría de movimientos de stock.';

CREATE SCHEMA IF NOT EXISTS reservaciones;
COMMENT ON SCHEMA reservaciones IS 'Gestión de reservaciones de mesas por fecha y hora.';

CREATE SCHEMA IF NOT EXISTS lealtad;
COMMENT ON SCHEMA lealtad IS 'Programa de puntos con tarjetas anónimas (identificadas por número/teléfono).';


-- ============================================================
-- 2. FUNCIÓN GLOBAL: actualización automática de updated_at
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.set_updated_at() IS
  'Trigger que actualiza automáticamente la columna updated_at antes de cada UPDATE.';


-- ============================================================
-- 3. TIPOS ENUM
-- ============================================================

-- Estado genérico activo/inactivo
CREATE TYPE public.estado_general AS ENUM (
  'activo',
  'inactivo'
);

-- personal
CREATE TYPE personal.tipo_rol AS ENUM (
  'dueño',
  'gerente',
  'mesero',
  'cocina',
  'barra',
  'caja'
);

-- operaciones
CREATE TYPE operaciones.estado_mesa AS ENUM (
  'disponible',
  'ocupada',
  'reservada',
  'en_limpieza',
  'fuera_de_servicio'
);

CREATE TYPE operaciones.estado_sesion AS ENUM (
  'activa',
  'cerrada',
  'cancelada'
);

CREATE TYPE operaciones.estado_orden AS ENUM (
  'borrador',
  'confirmada',
  'en_preparacion',
  'lista',
  'entregada',
  'cancelada'
);

CREATE TYPE operaciones.destino_preparacion AS ENUM (
  'cocina',
  'barra',
  'mostrador'
);

CREATE TYPE operaciones.tipo_solicitud AS ENUM (
  'llamar_mesero',
  'agua',
  'servilletas',
  'limpieza',
  'cuenta',
  'otro'
);

CREATE TYPE operaciones.estado_solicitud AS ENUM (
  'pendiente',
  'atendida',
  'cancelada'
);

CREATE TYPE operaciones.estado_item AS ENUM (
  'pendiente',
  'en_preparacion',
  'listo',
  'entregado',
  'cancelado'
);

-- pagos
CREATE TYPE pagos.metodo_pago AS ENUM (
  'efectivo',
  'tarjeta_credito',
  'tarjeta_debito',
  'transferencia',
  'qr_pago',
  'puntos_lealtad',
  'otro'
);

CREATE TYPE pagos.estado_pago AS ENUM (
  'pendiente',
  'pagado',
  'reembolsado',
  'fallido'
);

-- inventario
CREATE TYPE inventario.tipo_movimiento AS ENUM (
  'entrada',
  'salida',
  'ajuste',
  'merma',
  'produccion'
);

-- reservaciones
CREATE TYPE reservaciones.estado_reservacion AS ENUM (
  'pendiente',
  'confirmada',
  'cancelada',
  'no_presentado',
  'completada'
);

-- lealtad
CREATE TYPE lealtad.tipo_movimiento_puntos AS ENUM (
  'acumulacion',
  'canje',
  'ajuste',
  'vencimiento'
);


-- ============================================================
-- 4. ESQUEMA: config
-- ============================================================

CREATE TABLE config.establecimiento (
  id                   UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre               VARCHAR(150) NOT NULL,
  slogan               VARCHAR(255),
  logo_url             TEXT,
  direccion            TEXT,
  telefono             VARCHAR(30),
  email                VARCHAR(150),
  -- Preparado para facturación electrónica futura (CFDI)
  rfc                  VARCHAR(20),
  razon_social         VARCHAR(255),
  regimen_fiscal       VARCHAR(150),
  codigo_postal_fiscal CHAR(5),
  -- Configuración operativa
  wifi_ssid            VARCHAR(100),
  timezone             VARCHAR(60)  NOT NULL DEFAULT 'America/Mexico_City',
  moneda               CHAR(3)      NOT NULL DEFAULT 'MXN',
  porcentaje_iva       NUMERIC(5,2) NOT NULL DEFAULT 16.00,
  mensaje_ticket       TEXT,
  configuracion_extra  JSONB        NOT NULL DEFAULT '{}',
  created_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  config.establecimiento IS 'Configuración única del restaurante. Solo debe existir un registro.';
COMMENT ON COLUMN config.establecimiento.rfc IS 'RFC preparado para facturación electrónica CFDI futura.';
COMMENT ON COLUMN config.establecimiento.wifi_ssid IS 'Red WiFi local. El sistema opera sin Internet externo.';
COMMENT ON COLUMN config.establecimiento.configuracion_extra IS 'JSON extensible para parámetros adicionales.';

CREATE TRIGGER trg_establecimiento_updated_at
  BEFORE UPDATE ON config.establecimiento
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Zonas del restaurante
CREATE TABLE config.zonas (
  id          UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre      VARCHAR(100)  NOT NULL,
  descripcion TEXT,
  color_hex   CHAR(7),
  icono       VARCHAR(100),
  orden       SMALLINT      NOT NULL DEFAULT 0,
  estado      public.estado_general NOT NULL DEFAULT 'activo',
  created_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at  TIMESTAMPTZ
);

COMMENT ON TABLE config.zonas IS 'Áreas o zonas del restaurante (Salón principal, Terraza, Barra, etc.).';

CREATE INDEX idx_zonas_estado ON config.zonas(estado) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_zonas_updated_at
  BEFORE UPDATE ON config.zonas
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Impresoras térmicas
CREATE TABLE config.impresoras_termicas (
  id         UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre     VARCHAR(100)  NOT NULL,
  modelo     VARCHAR(100),
  ip_address INET,
  puerto     SMALLINT               DEFAULT 9100,
  usb_path   VARCHAR(100),
  destino    operaciones.destino_preparacion,
  es_ticket  BOOLEAN       NOT NULL DEFAULT FALSE,
  estado     public.estado_general NOT NULL DEFAULT 'activo',
  created_at TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  config.impresoras_termicas IS 'Impresoras térmicas configuradas: cocina, barra, caja.';
COMMENT ON COLUMN config.impresoras_termicas.es_ticket IS 'TRUE = impresora de tickets/cuentas de venta.';

CREATE TRIGGER trg_impresoras_updated_at
  BEFORE UPDATE ON config.impresoras_termicas
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Pantallas KDS (Kitchen Display System)
CREATE TABLE config.pantallas_cocina (
  id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre       VARCHAR(100) NOT NULL,
  destino      operaciones.destino_preparacion NOT NULL,
  ip_address   INET,
  token_acceso UUID         NOT NULL DEFAULT gen_random_uuid(),
  estado       public.estado_general NOT NULL DEFAULT 'activo',
  created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  config.pantallas_cocina IS 'Pantallas KDS para cocina y barra. Se autentican con token.';
COMMENT ON COLUMN config.pantallas_cocina.token_acceso IS 'Token UUID que permite acceso sin credenciales de usuario.';

CREATE UNIQUE INDEX idx_pantallas_token ON config.pantallas_cocina(token_acceso);

CREATE TRIGGER trg_pantallas_updated_at
  BEFORE UPDATE ON config.pantallas_cocina
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ============================================================
-- 5. ESQUEMA: personal
-- ============================================================

CREATE TABLE personal.roles (
  id          UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre      VARCHAR(100)  NOT NULL UNIQUE,
  tipo        personal.tipo_rol NOT NULL,
  descripcion TEXT,
  permisos    JSONB         NOT NULL DEFAULT '{}',
  estado      public.estado_general NOT NULL DEFAULT 'activo',
  created_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  personal.roles IS 'Roles del personal con permisos configurables por módulo.';
COMMENT ON COLUMN personal.roles.permisos IS 'JSON de permisos por módulo. Ej: {"menu": {"ver": true, "editar": false}}.';

CREATE INDEX idx_roles_tipo ON personal.roles(tipo);

CREATE TRIGGER trg_roles_updated_at
  BEFORE UPDATE ON personal.roles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE personal.usuarios (
  id            UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  rol_id        UUID          NOT NULL REFERENCES personal.roles(id),
  nombre        VARCHAR(150)  NOT NULL,
  apellido      VARCHAR(150),
  email         VARCHAR(200)  UNIQUE,
  username      VARCHAR(80)   NOT NULL UNIQUE,
  password_hash TEXT          NOT NULL,
  pin           CHAR(6),
  foto_url      TEXT,
  estado        public.estado_general NOT NULL DEFAULT 'activo',
  ultimo_login  TIMESTAMPTZ,
  created_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at    TIMESTAMPTZ
);

COMMENT ON TABLE  personal.usuarios IS 'Personal del restaurante con acceso al sistema.';
COMMENT ON COLUMN personal.usuarios.pin IS 'PIN de 6 dígitos para acceso rápido desde tablets. Almacenar hasheado.';
COMMENT ON COLUMN personal.usuarios.password_hash IS 'Hash de contraseña. Usar bcrypt o argon2id.';

CREATE INDEX idx_usuarios_rol     ON personal.usuarios(rol_id);
CREATE INDEX idx_usuarios_username ON personal.usuarios(username);
CREATE INDEX idx_usuarios_estado  ON personal.usuarios(estado) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_usuarios_updated_at
  BEFORE UPDATE ON personal.usuarios
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE personal.sesiones_usuario (
  id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id  UUID         NOT NULL REFERENCES personal.usuarios(id) ON DELETE CASCADE,
  token       TEXT         NOT NULL UNIQUE,
  dispositivo VARCHAR(200),
  ip_address  INET,
  expira_en   TIMESTAMPTZ  NOT NULL,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE personal.sesiones_usuario IS 'Tokens de sesión activos del personal. Purgar los expirados periódicamente.';

CREATE INDEX idx_sesiones_usuario_id ON personal.sesiones_usuario(usuario_id);
CREATE INDEX idx_sesiones_token      ON personal.sesiones_usuario(token);
CREATE INDEX idx_sesiones_expira     ON personal.sesiones_usuario(expira_en);


-- ============================================================
-- 6. ESQUEMA: menu
-- ============================================================

CREATE TABLE menu.categorias (
  id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre           VARCHAR(150) NOT NULL,
  descripcion      TEXT,
  imagen_url       TEXT,
  color_hex        CHAR(7),
  icono            VARCHAR(100),
  orden            SMALLINT     NOT NULL DEFAULT 0,
  disponible_desde TIME,
  disponible_hasta TIME,
  estado           public.estado_general NOT NULL DEFAULT 'activo',
  created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  deleted_at       TIMESTAMPTZ
);

COMMENT ON TABLE  menu.categorias IS 'Categorías del menú (Entradas, Bebidas, Postres, Desayunos, etc.).';
COMMENT ON COLUMN menu.categorias.disponible_desde IS 'Hora de inicio de disponibilidad. NULL = todo el día.';
COMMENT ON COLUMN menu.categorias.disponible_hasta IS 'Hora de fin de disponibilidad. NULL = todo el día.';

CREATE INDEX idx_categorias_estado ON menu.categorias(estado) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_categorias_updated_at
  BEFORE UPDATE ON menu.categorias
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE menu.productos (
  id                  UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  categoria_id        UUID          NOT NULL REFERENCES menu.categorias(id),
  nombre              VARCHAR(200)  NOT NULL,
  descripcion         TEXT,
  imagen_url          TEXT,
  precio              NUMERIC(10,2) NOT NULL CHECK (precio >= 0),
  precio_costo        NUMERIC(10,2),
  tiempo_prep_min     SMALLINT,
  destino             operaciones.destino_preparacion NOT NULL DEFAULT 'cocina',
  es_vegano           BOOLEAN       NOT NULL DEFAULT FALSE,
  es_vegetariano      BOOLEAN       NOT NULL DEFAULT FALSE,
  es_sin_gluten       BOOLEAN       NOT NULL DEFAULT FALSE,
  contiene_alergenos  TEXT[],
  calorias            SMALLINT,
  tags                TEXT[],
  orden               SMALLINT      NOT NULL DEFAULT 0,
  disponible          BOOLEAN       NOT NULL DEFAULT TRUE,
  estado              public.estado_general NOT NULL DEFAULT 'activo',
  -- Preparado para facturación CFDI
  datos_fiscales      JSONB,
  created_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at          TIMESTAMPTZ
);

COMMENT ON TABLE  menu.productos IS 'Catálogo completo de productos del menú.';
COMMENT ON COLUMN menu.productos.destino IS 'Estación de preparación: cocina o barra.';
COMMENT ON COLUMN menu.productos.precio_costo IS 'Costo de producción para cálculo de margen.';
COMMENT ON COLUMN menu.productos.datos_fiscales IS 'Para CFDI: {"clave_sat": "...", "unidad_sat": "H87", "objeto_imp": "02"}.';

CREATE INDEX idx_productos_categoria  ON menu.productos(categoria_id);
CREATE INDEX idx_productos_disponible ON menu.productos(disponible, estado) WHERE deleted_at IS NULL;
CREATE INDEX idx_productos_destino    ON menu.productos(destino);
CREATE INDEX idx_productos_tags       ON menu.productos USING GIN(tags);

CREATE TRIGGER trg_productos_updated_at
  BEFORE UPDATE ON menu.productos
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE menu.variantes_producto (
  id           UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  producto_id  UUID          NOT NULL REFERENCES menu.productos(id) ON DELETE CASCADE,
  nombre       VARCHAR(150)  NOT NULL,
  precio_extra NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (precio_extra >= 0),
  orden        SMALLINT      NOT NULL DEFAULT 0,
  disponible   BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE menu.variantes_producto IS 'Variantes de tamaño o presentación (Pequeño/Mediano/Grande, etc.).';

CREATE INDEX idx_variantes_producto ON menu.variantes_producto(producto_id);

CREATE TRIGGER trg_variantes_updated_at
  BEFORE UPDATE ON menu.variantes_producto
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE menu.grupos_modificadores (
  id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre            VARCHAR(150) NOT NULL,
  descripcion       TEXT,
  seleccion_minima  SMALLINT     NOT NULL DEFAULT 0,
  seleccion_maxima  SMALLINT     NOT NULL DEFAULT 1,
  obligatorio       BOOLEAN      NOT NULL DEFAULT FALSE,
  orden             SMALLINT     NOT NULL DEFAULT 0,
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  menu.grupos_modificadores IS 'Agrupaciones de personalizaciones (Término, Extras, Sin ingrediente, etc.).';
COMMENT ON COLUMN menu.grupos_modificadores.seleccion_maxima IS '1 = selección única (radio). >1 = múltiple con límite.';

CREATE TRIGGER trg_grupos_mod_updated_at
  BEFORE UPDATE ON menu.grupos_modificadores
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE menu.modificadores (
  id           UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  grupo_id     UUID          NOT NULL REFERENCES menu.grupos_modificadores(id) ON DELETE CASCADE,
  nombre       VARCHAR(150)  NOT NULL,
  precio_extra NUMERIC(10,2) NOT NULL DEFAULT 0,
  orden        SMALLINT      NOT NULL DEFAULT 0,
  disponible   BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE menu.modificadores IS 'Opciones individuales de personalización (Sin cebolla, Extra salsa, etc.).';

CREATE INDEX idx_modificadores_grupo ON menu.modificadores(grupo_id);

CREATE TRIGGER trg_modificadores_updated_at
  BEFORE UPDATE ON menu.modificadores
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE menu.producto_grupos_modificadores (
  producto_id  UUID     NOT NULL REFERENCES menu.productos(id) ON DELETE CASCADE,
  grupo_id     UUID     NOT NULL REFERENCES menu.grupos_modificadores(id) ON DELETE CASCADE,
  orden        SMALLINT NOT NULL DEFAULT 0,
  PRIMARY KEY (producto_id, grupo_id)
);

COMMENT ON TABLE menu.producto_grupos_modificadores IS 'Qué grupos de modificadores aplican a cada producto.';

CREATE INDEX idx_pgm_grupo ON menu.producto_grupos_modificadores(grupo_id);

CREATE TABLE menu.paquetes (
  id           UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre       VARCHAR(200)  NOT NULL,
  descripcion  TEXT,
  imagen_url   TEXT,
  precio       NUMERIC(10,2) NOT NULL CHECK (precio >= 0),
  disponible   BOOLEAN       NOT NULL DEFAULT TRUE,
  fecha_inicio DATE,
  fecha_fin    DATE,
  orden        SMALLINT      NOT NULL DEFAULT 0,
  estado       public.estado_general NOT NULL DEFAULT 'activo',
  created_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at   TIMESTAMPTZ
);

COMMENT ON TABLE menu.paquetes IS 'Combos o paquetes con precio especial.';

CREATE INDEX idx_paquetes_disponible ON menu.paquetes(disponible, estado) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_paquetes_updated_at
  BEFORE UPDATE ON menu.paquetes
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE menu.paquete_items (
  id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  paquete_id  UUID         NOT NULL REFERENCES menu.paquetes(id) ON DELETE CASCADE,
  producto_id UUID         REFERENCES menu.productos(id),
  nombre_item VARCHAR(200),
  cantidad    SMALLINT     NOT NULL DEFAULT 1 CHECK (cantidad > 0),
  orden       SMALLINT     NOT NULL DEFAULT 0
);

COMMENT ON TABLE  menu.paquete_items IS 'Productos que conforman cada paquete/combo.';
COMMENT ON COLUMN menu.paquete_items.nombre_item IS 'Descripción libre cuando el ítem no corresponde a un producto del catálogo.';

CREATE INDEX idx_paquete_items_paquete ON menu.paquete_items(paquete_id);


-- ============================================================
-- 7. ESQUEMA: inventario
-- ============================================================

CREATE TABLE inventario.unidades_medida (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre      VARCHAR(80) NOT NULL UNIQUE,
  abreviatura VARCHAR(10) NOT NULL UNIQUE,
  tipo        VARCHAR(50)
);

COMMENT ON TABLE inventario.unidades_medida IS 'Catálogo de unidades de medida (gramo, litro, pieza, etc.).';

CREATE TABLE inventario.ingredientes (
  id             UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre         VARCHAR(200)  NOT NULL,
  unidad_id      UUID          NOT NULL REFERENCES inventario.unidades_medida(id),
  stock_actual   NUMERIC(12,3) NOT NULL DEFAULT 0,
  stock_minimo   NUMERIC(12,3) NOT NULL DEFAULT 0,
  stock_maximo   NUMERIC(12,3),
  costo_unitario NUMERIC(10,4),
  codigo_barras  VARCHAR(100),
  proveedor      VARCHAR(200),
  notas          TEXT,
  estado         public.estado_general NOT NULL DEFAULT 'activo',
  created_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at     TIMESTAMPTZ
);

COMMENT ON TABLE  inventario.ingredientes IS 'Ingredientes y materias primas con control de stock.';
COMMENT ON COLUMN inventario.ingredientes.stock_minimo IS 'Umbral de alerta: stock_actual <= stock_minimo genera aviso.';

CREATE INDEX idx_ingredientes_stock  ON inventario.ingredientes(stock_actual);
CREATE INDEX idx_ingredientes_estado ON inventario.ingredientes(estado) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_ingredientes_updated_at
  BEFORE UPDATE ON inventario.ingredientes
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE inventario.producto_ingredientes (
  id             UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  producto_id    UUID          NOT NULL REFERENCES menu.productos(id) ON DELETE CASCADE,
  ingrediente_id UUID          NOT NULL REFERENCES inventario.ingredientes(id),
  cantidad       NUMERIC(12,3) NOT NULL CHECK (cantidad > 0),
  unidad_id      UUID          NOT NULL REFERENCES inventario.unidades_medida(id),
  UNIQUE (producto_id, ingrediente_id)
);

COMMENT ON TABLE inventario.producto_ingredientes IS 'Receta de cada producto: ingredientes y cantidades por unidad producida.';

CREATE INDEX idx_prod_ing_producto    ON inventario.producto_ingredientes(producto_id);
CREATE INDEX idx_prod_ing_ingrediente ON inventario.producto_ingredientes(ingrediente_id);

-- Nota: FK a operaciones.ordenes se agrega con ALTER TABLE al final.
CREATE TABLE inventario.movimientos_inventario (
  id             UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  ingrediente_id UUID          NOT NULL REFERENCES inventario.ingredientes(id),
  tipo           inventario.tipo_movimiento NOT NULL,
  cantidad       NUMERIC(12,3) NOT NULL,
  stock_antes    NUMERIC(12,3) NOT NULL,
  stock_despues  NUMERIC(12,3) NOT NULL,
  costo_unitario NUMERIC(10,4),
  orden_id       UUID,
  usuario_id     UUID          REFERENCES personal.usuarios(id),
  notas          TEXT,
  created_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  inventario.movimientos_inventario IS 'Registro completo de movimientos de stock (entradas, salidas, mermas, ajustes).';
COMMENT ON COLUMN inventario.movimientos_inventario.orden_id IS 'Orden que originó el movimiento. NULL para movimientos manuales.';

CREATE INDEX idx_mov_inv_ingrediente ON inventario.movimientos_inventario(ingrediente_id);
CREATE INDEX idx_mov_inv_tipo        ON inventario.movimientos_inventario(tipo);
CREATE INDEX idx_mov_inv_fecha       ON inventario.movimientos_inventario(created_at);
CREATE INDEX idx_mov_inv_orden       ON inventario.movimientos_inventario(orden_id);


-- ============================================================
-- 8. ESQUEMA: operaciones
-- ============================================================

CREATE TABLE operaciones.mesas (
  id         UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  zona_id    UUID          NOT NULL REFERENCES config.zonas(id),
  numero     VARCHAR(20)   NOT NULL,
  nombre     VARCHAR(100),
  capacidad  SMALLINT      NOT NULL DEFAULT 4 CHECK (capacidad > 0),
  estado     operaciones.estado_mesa NOT NULL DEFAULT 'disponible',
  posicion_x NUMERIC(6,2),
  posicion_y NUMERIC(6,2),
  created_at TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  UNIQUE (zona_id, numero)
);

COMMENT ON TABLE operaciones.mesas IS 'Mesas del restaurante por zona. Número único dentro de cada zona.';

CREATE INDEX idx_mesas_zona   ON operaciones.mesas(zona_id);
CREATE INDEX idx_mesas_estado ON operaciones.mesas(estado) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_mesas_updated_at
  BEFORE UPDATE ON operaciones.mesas
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE operaciones.qr_codes (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  mesa_id     UUID        NOT NULL REFERENCES operaciones.mesas(id) ON DELETE CASCADE,
  token       UUID        NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  url_destino TEXT GENERATED ALWAYS AS ('/menu?mesa=' || token::TEXT) STORED,
  activo      BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  operaciones.qr_codes IS 'Códigos QR de acceso al menú por mesa. Token genera la URL local.';
COMMENT ON COLUMN operaciones.qr_codes.token IS 'UUID único: URL local /menu?mesa={token}. Sin Internet.';

CREATE INDEX idx_qr_mesa  ON operaciones.qr_codes(mesa_id);
CREATE UNIQUE INDEX idx_qr_token ON operaciones.qr_codes(token);

CREATE TRIGGER trg_qr_updated_at
  BEFORE UPDATE ON operaciones.qr_codes
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Nota: columna tarjeta_lealtad_id se agrega al final del script.
CREATE TABLE operaciones.sesiones_mesa (
  id             UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  mesa_id        UUID         NOT NULL REFERENCES operaciones.mesas(id),
  mesero_id      UUID         REFERENCES personal.usuarios(id),
  estado         operaciones.estado_sesion NOT NULL DEFAULT 'activa',
  num_comensales SMALLINT     NOT NULL DEFAULT 1 CHECK (num_comensales > 0),
  notas_internas TEXT,
  iniciada_en    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  cerrada_en     TIMESTAMPTZ,
  created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  operaciones.sesiones_mesa IS 'Cada visita en una mesa. Agrupa todas las órdenes de esa visita.';
COMMENT ON COLUMN operaciones.sesiones_mesa.mesero_id IS 'Mesero responsable de la mesa durante esta sesión.';

CREATE INDEX idx_sesiones_mesa_id ON operaciones.sesiones_mesa(mesa_id);
CREATE INDEX idx_sesiones_mesero  ON operaciones.sesiones_mesa(mesero_id);
CREATE INDEX idx_sesiones_estado  ON operaciones.sesiones_mesa(estado);
CREATE INDEX idx_sesiones_fecha   ON operaciones.sesiones_mesa(iniciada_en);

CREATE TRIGGER trg_sesiones_mesa_updated_at
  BEFORE UPDATE ON operaciones.sesiones_mesa
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE operaciones.ordenes (
  id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  sesion_id    UUID         NOT NULL REFERENCES operaciones.sesiones_mesa(id),
  numero_orden INTEGER,
  estado       operaciones.estado_orden NOT NULL DEFAULT 'borrador',
  tomada_por   UUID         REFERENCES personal.usuarios(id),
  notas        TEXT,
  es_takeout   BOOLEAN      NOT NULL DEFAULT FALSE,
  created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  deleted_at   TIMESTAMPTZ
);

COMMENT ON TABLE  operaciones.ordenes IS 'Órdenes de pedido. Una sesión puede tener múltiples órdenes.';
COMMENT ON COLUMN operaciones.ordenes.tomada_por IS 'NULL = cliente ordenó vía QR desde su celular.';
COMMENT ON COLUMN operaciones.ordenes.numero_orden IS 'Número visible en cocina, asignado al confirmar.';

CREATE INDEX idx_ordenes_sesion ON operaciones.ordenes(sesion_id);
CREATE INDEX idx_ordenes_estado ON operaciones.ordenes(estado) WHERE deleted_at IS NULL;
CREATE INDEX idx_ordenes_fecha  ON operaciones.ordenes(created_at);

CREATE TRIGGER trg_ordenes_updated_at
  BEFORE UPDATE ON operaciones.ordenes
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE operaciones.orden_items (
  id                  UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  orden_id            UUID          NOT NULL REFERENCES operaciones.ordenes(id) ON DELETE CASCADE,
  producto_id         UUID          NOT NULL REFERENCES menu.productos(id),
  variante_id         UUID          REFERENCES menu.variantes_producto(id),
  paquete_id          UUID          REFERENCES menu.paquetes(id),
  cantidad            SMALLINT      NOT NULL DEFAULT 1 CHECK (cantidad > 0),
  precio_unitario     NUMERIC(10,2) NOT NULL,
  precio_total        NUMERIC(10,2) NOT NULL,
  destino             operaciones.destino_preparacion NOT NULL,
  estado              operaciones.estado_item NOT NULL DEFAULT 'pendiente',
  notas_especiales    TEXT,
  enviado_a_cocina_en TIMESTAMPTZ,
  listo_en            TIMESTAMPTZ,
  entregado_en        TIMESTAMPTZ,
  created_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  operaciones.orden_items IS 'Productos individuales dentro de una orden con precio histórico.';
COMMENT ON COLUMN operaciones.orden_items.precio_unitario IS 'Precio al momento de ordenar para preservar histórico.';

CREATE INDEX idx_orden_items_orden    ON operaciones.orden_items(orden_id);
CREATE INDEX idx_orden_items_producto ON operaciones.orden_items(producto_id);
CREATE INDEX idx_orden_items_estado   ON operaciones.orden_items(estado);
CREATE INDEX idx_orden_items_destino  ON operaciones.orden_items(destino, estado);

CREATE TRIGGER trg_orden_items_updated_at
  BEFORE UPDATE ON operaciones.orden_items
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE operaciones.orden_item_modificadores (
  id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  orden_item_id   UUID          NOT NULL REFERENCES operaciones.orden_items(id) ON DELETE CASCADE,
  modificador_id  UUID          NOT NULL REFERENCES menu.modificadores(id),
  nombre_snapshot VARCHAR(150)  NOT NULL,
  precio_extra    NUMERIC(10,2) NOT NULL DEFAULT 0
);

COMMENT ON TABLE  operaciones.orden_item_modificadores IS 'Modificadores aplicados a cada ítem de orden.';
COMMENT ON COLUMN operaciones.orden_item_modificadores.nombre_snapshot IS 'Copia del nombre para preservar histórico.';

CREATE INDEX idx_mod_item ON operaciones.orden_item_modificadores(orden_item_id);

CREATE TABLE operaciones.solicitudes_atencion (
  id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  sesion_id    UUID         NOT NULL REFERENCES operaciones.sesiones_mesa(id),
  tipo         operaciones.tipo_solicitud NOT NULL,
  descripcion  TEXT,
  estado       operaciones.estado_solicitud NOT NULL DEFAULT 'pendiente',
  atendida_por UUID         REFERENCES personal.usuarios(id),
  atendida_en  TIMESTAMPTZ,
  created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE operaciones.solicitudes_atencion IS 'Solicitudes del cliente desde su celular (agua, limpieza, cuenta, mesero).';

CREATE INDEX idx_solicitudes_sesion ON operaciones.solicitudes_atencion(sesion_id);
CREATE INDEX idx_solicitudes_estado ON operaciones.solicitudes_atencion(estado);
CREATE INDEX idx_solicitudes_fecha  ON operaciones.solicitudes_atencion(created_at);

CREATE TRIGGER trg_solicitudes_updated_at
  BEFORE UPDATE ON operaciones.solicitudes_atencion
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- FK diferida: movimientos_inventario → ordenes
ALTER TABLE inventario.movimientos_inventario
  ADD CONSTRAINT fk_mov_inv_orden
  FOREIGN KEY (orden_id) REFERENCES operaciones.ordenes(id);


-- ============================================================
-- 9. ESQUEMA: pagos
-- ============================================================

CREATE TABLE pagos.cuentas (
  id               UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  sesion_id        UUID          NOT NULL REFERENCES operaciones.sesiones_mesa(id),
  subtotal         NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (subtotal >= 0),
  descuento        NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (descuento >= 0),
  impuestos        NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (impuestos >= 0),
  total            NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (total >= 0),
  estado           pagos.estado_pago NOT NULL DEFAULT 'pendiente',
  dividida_en      SMALLINT      NOT NULL DEFAULT 1 CHECK (dividida_en >= 1),
  notas            TEXT,
  -- Preparado para facturación electrónica CFDI futura
  requiere_factura BOOLEAN       NOT NULL DEFAULT FALSE,
  uuid_cfdi        UUID,
  folio_fiscal     VARCHAR(100),
  datos_fiscales   JSONB,
  created_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  pagos.cuentas IS 'Cuenta consolidada de una sesión. Puede dividirse en múltiples pagos.';
COMMENT ON COLUMN pagos.cuentas.dividida_en IS '1 = cuenta completa, N = dividida en N partes.';
COMMENT ON COLUMN pagos.cuentas.datos_fiscales IS 'Para CFDI: {"rfc": "...", "razon_social": "...", "uso_cfdi": "G03"}.';

CREATE INDEX idx_cuentas_sesion ON pagos.cuentas(sesion_id);
CREATE INDEX idx_cuentas_estado ON pagos.cuentas(estado);
CREATE INDEX idx_cuentas_fecha  ON pagos.cuentas(created_at);

CREATE TRIGGER trg_cuentas_updated_at
  BEFORE UPDATE ON pagos.cuentas
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE pagos.pagos (
  id            UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  cuenta_id     UUID          NOT NULL REFERENCES pagos.cuentas(id),
  metodo        pagos.metodo_pago NOT NULL,
  monto         NUMERIC(10,2) NOT NULL CHECK (monto > 0),
  propina       NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (propina >= 0),
  cambio        NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (cambio >= 0),
  referencia    VARCHAR(200),
  estado        pagos.estado_pago NOT NULL DEFAULT 'pendiente',
  procesado_por UUID          REFERENCES personal.usuarios(id),
  created_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  pagos.pagos IS 'Transacciones de pago individuales. Cuenta dividida = múltiples registros.';
COMMENT ON COLUMN pagos.pagos.propina IS 'Propina registrada por separado al monto del consumo.';
COMMENT ON COLUMN pagos.pagos.referencia IS 'Autorización de terminal, folio de transferencia o referencia QR.';

CREATE INDEX idx_pagos_cuenta ON pagos.pagos(cuenta_id);
CREATE INDEX idx_pagos_metodo ON pagos.pagos(metodo);
CREATE INDEX idx_pagos_fecha  ON pagos.pagos(created_at);

CREATE TRIGGER trg_pagos_updated_at
  BEFORE UPDATE ON pagos.pagos
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE pagos.pago_items (
  id             UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  pago_id        UUID          NOT NULL REFERENCES pagos.pagos(id) ON DELETE CASCADE,
  orden_item_id  UUID          NOT NULL REFERENCES operaciones.orden_items(id),
  monto_asignado NUMERIC(10,2) NOT NULL CHECK (monto_asignado > 0)
);

COMMENT ON TABLE pagos.pago_items IS 'Ítems cubiertos por cada pago. Permite dividir la cuenta por persona.';

CREATE INDEX idx_pago_items_pago ON pagos.pago_items(pago_id);


-- ============================================================
-- 10. ESQUEMA: reservaciones
-- ============================================================

CREATE TABLE reservaciones.reservaciones (
  id                   UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  mesa_id              UUID         REFERENCES operaciones.mesas(id),
  nombre_contacto      VARCHAR(200) NOT NULL,
  telefono             VARCHAR(30)  NOT NULL,
  email                VARCHAR(150),
  num_personas         SMALLINT     NOT NULL DEFAULT 2 CHECK (num_personas > 0),
  fecha_hora           TIMESTAMPTZ  NOT NULL,
  duracion_min         SMALLINT     NOT NULL DEFAULT 90 CHECK (duracion_min > 0),
  estado               reservaciones.estado_reservacion NOT NULL DEFAULT 'pendiente',
  notas                TEXT,
  codigo               VARCHAR(20)  NOT NULL UNIQUE,
  recordatorio_enviado BOOLEAN      NOT NULL DEFAULT FALSE,
  creada_por           UUID         REFERENCES personal.usuarios(id),
  created_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  reservaciones.reservaciones IS 'Gestión de reservaciones por fecha y hora.';
COMMENT ON COLUMN reservaciones.reservaciones.codigo IS 'Código corto de confirmación (ej: RES-0042) para el cliente.';
COMMENT ON COLUMN reservaciones.reservaciones.creada_por IS 'NULL = reservación hecha por el cliente vía web/celular.';

CREATE INDEX idx_reservaciones_fecha  ON reservaciones.reservaciones(fecha_hora);
CREATE INDEX idx_reservaciones_mesa   ON reservaciones.reservaciones(mesa_id);
CREATE INDEX idx_reservaciones_estado ON reservaciones.reservaciones(estado);
CREATE INDEX idx_reservaciones_codigo ON reservaciones.reservaciones(codigo);

CREATE TRIGGER trg_reservaciones_updated_at
  BEFORE UPDATE ON reservaciones.reservaciones
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ============================================================
-- 11. ESQUEMA: lealtad
--
-- Clientes siempre anónimos. El programa de puntos se identifica
-- por número de tarjeta física o número de teléfono, sin cuenta.
-- ============================================================

CREATE TABLE lealtad.tarjetas (
  id                 UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  numero             VARCHAR(30)  NOT NULL UNIQUE,
  alias              VARCHAR(150),
  puntos_acumulados  INTEGER      NOT NULL DEFAULT 0 CHECK (puntos_acumulados >= 0),
  puntos_canjeados   INTEGER      NOT NULL DEFAULT 0 CHECK (puntos_canjeados >= 0),
  puntos_disponibles INTEGER GENERATED ALWAYS AS
                       (puntos_acumulados - puntos_canjeados) STORED,
  estado             public.estado_general NOT NULL DEFAULT 'activo',
  created_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  lealtad.tarjetas IS 'Tarjetas de lealtad anónimas. Identificadas por teléfono o número de tarjeta.';
COMMENT ON COLUMN lealtad.tarjetas.numero IS 'Identificador único: número de teléfono, tarjeta física o código generado.';
COMMENT ON COLUMN lealtad.tarjetas.puntos_disponibles IS 'Columna calculada: acumulados - canjeados.';

CREATE INDEX idx_tarjetas_numero ON lealtad.tarjetas(numero);

CREATE TRIGGER trg_tarjetas_updated_at
  BEFORE UPDATE ON lealtad.tarjetas
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE lealtad.reglas_puntos (
  id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre          VARCHAR(150)  NOT NULL,
  descripcion     TEXT,
  puntos_por_peso NUMERIC(6,4)  NOT NULL DEFAULT 0.1,
  monto_minimo    NUMERIC(10,2) NOT NULL DEFAULT 0,
  valor_por_punto NUMERIC(6,4)  NOT NULL DEFAULT 0.10,
  vigente_desde   DATE,
  vigente_hasta   DATE,
  activa          BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  lealtad.reglas_puntos IS 'Reglas activas de acumulación y canje del programa de lealtad.';
COMMENT ON COLUMN lealtad.reglas_puntos.puntos_por_peso IS 'Ej: 0.1 = 1 punto por cada $10 gastados.';
COMMENT ON COLUMN lealtad.reglas_puntos.valor_por_punto IS 'Ej: 0.10 = cada punto vale $0.10 MXN al canjear.';

CREATE TRIGGER trg_reglas_puntos_updated_at
  BEFORE UPDATE ON lealtad.reglas_puntos
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE lealtad.movimientos_puntos (
  id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tarjeta_id      UUID          NOT NULL REFERENCES lealtad.tarjetas(id),
  tipo            lealtad.tipo_movimiento_puntos NOT NULL,
  puntos          INTEGER       NOT NULL,
  saldo_anterior  INTEGER       NOT NULL,
  saldo_posterior INTEGER       NOT NULL,
  pago_id         UUID          REFERENCES pagos.pagos(id),
  regla_id        UUID          REFERENCES lealtad.reglas_puntos(id),
  descripcion     TEXT,
  procesado_por   UUID          REFERENCES personal.usuarios(id),
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  lealtad.movimientos_puntos IS 'Historial de acumulaciones, canjes y ajustes de puntos.';
COMMENT ON COLUMN lealtad.movimientos_puntos.puntos IS 'Positivo = acumulación. Negativo = canje/vencimiento.';

CREATE INDEX idx_mov_puntos_tarjeta ON lealtad.movimientos_puntos(tarjeta_id);
CREATE INDEX idx_mov_puntos_tipo    ON lealtad.movimientos_puntos(tipo);
CREATE INDEX idx_mov_puntos_fecha   ON lealtad.movimientos_puntos(created_at);

-- FK diferida: sesiones_mesa → tarjetas (lealtad se creó después)
ALTER TABLE operaciones.sesiones_mesa
  ADD COLUMN tarjeta_lealtad_id UUID REFERENCES lealtad.tarjetas(id);

COMMENT ON COLUMN operaciones.sesiones_mesa.tarjeta_lealtad_id IS
  'Tarjeta de lealtad presentada al inicio o cierre de sesión para acumular puntos.';

CREATE INDEX idx_sesiones_tarjeta_lealtad ON operaciones.sesiones_mesa(tarjeta_lealtad_id)
  WHERE tarjeta_lealtad_id IS NOT NULL;


-- ============================================================
-- 12. DATOS INICIALES (seed)
-- ============================================================

-- Unidades de medida
INSERT INTO inventario.unidades_medida (nombre, abreviatura, tipo) VALUES
  ('Gramo',        'g',    'masa'),
  ('Kilogramo',    'kg',   'masa'),
  ('Litro',        'L',    'volumen'),
  ('Mililitro',    'mL',   'volumen'),
  ('Pieza',        'pza',  'conteo'),
  ('Porción',      'por',  'conteo'),
  ('Taza',         'tz',   'volumen'),
  ('Cucharada',    'cda',  'volumen'),
  ('Cucharadita',  'cdta', 'volumen'),
  ('Onza',         'oz',   'masa');

-- Roles del personal
INSERT INTO personal.roles (nombre, tipo, descripcion, permisos) VALUES
  (
    'Dueño / Director General', 'dueño',
    'Acceso total al sistema sin restricciones.',
    '{"*": true}'
  ),
  (
    'Gerente', 'gerente',
    'Gestión operativa completa: menú, mesas, inventario y reportes.',
    '{"menu": true, "mesas": true, "ordenes": true, "inventario": true,
      "reservaciones": true, "reportes": {"ver": true},
      "usuarios": {"ver": true, "editar": false}, "configuracion": {"ver": true, "editar": false}}'
  ),
  (
    'Mesero', 'mesero',
    'Toma de órdenes, atención a mesas y gestión de solicitudes.',
    '{"ordenes": {"ver": true, "crear": true, "editar": true},
      "mesas": {"ver": true}, "solicitudes": {"ver": true, "atender": true}}'
  ),
  (
    'Cocina', 'cocina',
    'Visualización y actualización de comandas de cocina.',
    '{"ordenes": {"ver": true, "estado": true}, "cocina": {"ver": true, "gestionar": true}}'
  ),
  (
    'Barra', 'barra',
    'Visualización y actualización de comandas de barra/bebidas.',
    '{"ordenes": {"ver": true, "estado": true}, "barra": {"ver": true, "gestionar": true}}'
  ),
  (
    'Caja', 'caja',
    'Gestión de pagos, cierre de cuentas y reportes de ventas.',
    '{"pagos": true, "cuentas": true, "reportes": {"ver": true}, "lealtad": true}'
  );

-- Zonas predeterminadas
INSERT INTO config.zonas (nombre, descripcion, color_hex, icono, orden) VALUES
  ('Salón Principal', 'Área principal del restaurante',  '#4F46E5', 'sofa',     1),
  ('Terraza',         'Área exterior con vista a calle', '#059669', 'tree',     2),
  ('Barra',           'Área de barra y bebidas',         '#D97706', 'wine',     3),
  ('Reservados',      'Salones privados y reservados',   '#DC2626', 'door',     4);

-- Establecimiento (registro inicial)
INSERT INTO config.establecimiento (
  nombre, slogan, direccion, timezone, moneda, porcentaje_iva, mensaje_ticket
) VALUES (
  'Sabor Urbano',
  'La mejor experiencia gastronómica de la ciudad',
  'Av. Principal 123, Col. Centro',
  'America/Mexico_City',
  'MXN',
  16.00,
  '¡Gracias por su visita! Esperamos verte pronto.'
);

-- Regla de lealtad inicial
INSERT INTO lealtad.reglas_puntos (
  nombre, descripcion, puntos_por_peso, monto_minimo, valor_por_punto, activa
) VALUES (
  'Regla estándar',
  '1 punto por cada $10 MXN gastados. Cada punto vale $0.10 al canjear.',
  0.1, 50.00, 0.10, TRUE
);

-- Grupos de modificadores comunes
INSERT INTO menu.grupos_modificadores
  (nombre, descripcion, seleccion_minima, seleccion_maxima, obligatorio, orden)
VALUES
  ('Término de cocción', 'Cómo deseas que se prepare tu carne',     1, 1, TRUE,  1),
  ('Extras',             'Ingredientes o porciones adicionales',     0, 5, FALSE, 2),
  ('Sin ingrediente',    'Indica qué quieres omitir del platillo',  0, 5, FALSE, 3),
  ('Tipo de tortilla',   'Elige el tipo de tortilla de tu orden',   0, 1, FALSE, 4),
  ('Tamaño de bebida',   'Selecciona el tamaño de tu bebida',       1, 1, TRUE,  5),
  ('Nivel de picante',   'Elige el nivel de picante a tu gusto',    0, 1, FALSE, 6);

-- Opciones de modificadores
INSERT INTO menu.modificadores (grupo_id, nombre, precio_extra, orden)
SELECT id, 'Rojo',         0.00, 1 FROM menu.grupos_modificadores WHERE nombre = 'Término de cocción' UNION ALL
SELECT id, 'Medio',        0.00, 2 FROM menu.grupos_modificadores WHERE nombre = 'Término de cocción' UNION ALL
SELECT id, 'Tres cuartos', 0.00, 3 FROM menu.grupos_modificadores WHERE nombre = 'Término de cocción' UNION ALL
SELECT id, 'Bien cocido',  0.00, 4 FROM menu.grupos_modificadores WHERE nombre = 'Término de cocción' UNION ALL
SELECT id, 'Sin picante',  0.00, 1 FROM menu.grupos_modificadores WHERE nombre = 'Nivel de picante'   UNION ALL
SELECT id, 'Poco picante', 0.00, 2 FROM menu.grupos_modificadores WHERE nombre = 'Nivel de picante'   UNION ALL
SELECT id, 'Muy picante',  0.00, 3 FROM menu.grupos_modificadores WHERE nombre = 'Nivel de picante'   UNION ALL
SELECT id, 'Chico',        0.00,  1 FROM menu.grupos_modificadores WHERE nombre = 'Tamaño de bebida'  UNION ALL
SELECT id, 'Mediano',     10.00,  2 FROM menu.grupos_modificadores WHERE nombre = 'Tamaño de bebida'  UNION ALL
SELECT id, 'Grande',      20.00,  3 FROM menu.grupos_modificadores WHERE nombre = 'Tamaño de bebida';


-- ============================================================
-- 13. VISTAS PARA REPORTES
-- ============================================================

-- Resumen de ventas del día por hora
CREATE OR REPLACE VIEW operaciones.v_resumen_ventas_hoy AS
SELECT
  DATE_TRUNC('hour', p.created_at)    AS hora,
  COUNT(DISTINCT p.id)                AS num_transacciones,
  SUM(p.monto)                        AS total_ventas,
  SUM(p.propina)                      AS total_propinas,
  SUM(p.monto + p.propina)            AS total_con_propina
FROM pagos.pagos p
WHERE p.estado = 'pagado'
  AND p.created_at >= CURRENT_DATE
  AND p.created_at <  CURRENT_DATE + INTERVAL '1 day'
GROUP BY DATE_TRUNC('hour', p.created_at)
ORDER BY hora;

COMMENT ON VIEW operaciones.v_resumen_ventas_hoy IS
  'Ventas del día agrupadas por hora, incluyendo propinas.';

-- Mesas actualmente en servicio
CREATE OR REPLACE VIEW operaciones.v_mesas_activas AS
SELECT
  m.numero                                            AS mesa,
  z.nombre                                            AS zona,
  sm.num_comensales,
  TRIM(u.nombre || ' ' || COALESCE(u.apellido, ''))   AS mesero,
  sm.iniciada_en,
  ROUND(EXTRACT(EPOCH FROM (NOW() - sm.iniciada_en)) / 60) AS minutos_activa,
  sm.id                                               AS sesion_id
FROM operaciones.sesiones_mesa sm
JOIN operaciones.mesas          m  ON m.id  = sm.mesa_id
JOIN config.zonas               z  ON z.id  = m.zona_id
LEFT JOIN personal.usuarios     u  ON u.id  = sm.mesero_id
WHERE sm.estado = 'activa'
ORDER BY sm.iniciada_en;

COMMENT ON VIEW operaciones.v_mesas_activas IS
  'Mesas en servicio activo con tiempo transcurrido y mesero asignado.';

-- Top 20 productos más vendidos
CREATE OR REPLACE VIEW operaciones.v_productos_mas_vendidos AS
SELECT
  p.nombre                      AS producto,
  cat.nombre                    AS categoria,
  SUM(oi.cantidad)              AS unidades_vendidas,
  SUM(oi.precio_total)          AS ingresos_total,
  COUNT(DISTINCT oi.orden_id)   AS num_ordenes
FROM operaciones.orden_items oi
JOIN menu.productos   p   ON p.id   = oi.producto_id
JOIN menu.categorias  cat ON cat.id = p.categoria_id
JOIN operaciones.ordenes o ON o.id  = oi.orden_id
WHERE o.estado NOT IN ('borrador', 'cancelada')
  AND o.deleted_at IS NULL
GROUP BY p.nombre, cat.nombre
ORDER BY unidades_vendidas DESC
LIMIT 20;

COMMENT ON VIEW operaciones.v_productos_mas_vendidos IS
  'Top 20 productos más vendidos con ingresos y número de órdenes.';

-- Alertas de stock bajo
CREATE OR REPLACE VIEW inventario.v_alertas_stock AS
SELECT
  i.nombre,
  u.abreviatura                        AS unidad,
  i.stock_actual,
  i.stock_minimo,
  (i.stock_minimo - i.stock_actual)    AS faltante,
  i.proveedor
FROM inventario.ingredientes    i
JOIN inventario.unidades_medida u ON u.id = i.unidad_id
WHERE i.stock_actual <= i.stock_minimo
  AND i.estado = 'activo'
  AND i.deleted_at IS NULL
ORDER BY faltante DESC;

COMMENT ON VIEW inventario.v_alertas_stock IS
  'Ingredientes cuyo stock actual está por debajo del mínimo configurado.';


-- ============================================================
-- FIN DEL SCRIPT
-- ============================================================
-- Tabla de contenido rápida:
--   0.  Extensiones       uuid-ossp, pgcrypto
--   1.  Esquemas          config · menu · personal · operaciones
--                         pagos · inventario · reservaciones · lealtad
--   2.  Función trigger   set_updated_at()
--   3.  Tipos ENUM        14 tipos distribuidos en sus esquemas
--   4.  config            establecimiento · zonas · impresoras · pantallas_cocina
--   5.  personal          roles · usuarios · sesiones_usuario
--   6.  menu              categorias · productos · variantes_producto
--                         grupos_modificadores · modificadores
--                         producto_grupos_modificadores · paquetes · paquete_items
--   7.  inventario        unidades_medida · ingredientes · producto_ingredientes
--                         movimientos_inventario
--   8.  operaciones       mesas · qr_codes · sesiones_mesa · ordenes
--                         orden_items · orden_item_modificadores
--                         solicitudes_atencion
--   9.  pagos             cuentas · pagos · pago_items
--  10.  reservaciones     reservaciones
--  11.  lealtad           tarjetas · reglas_puntos · movimientos_puntos
--  12.  Seed              unidades · roles · zonas · establecimiento
--                         regla de puntos · grupos/opciones de modificadores
--  13.  Vistas            v_resumen_ventas_hoy · v_mesas_activas
--                         v_productos_mas_vendidos · v_alertas_stock
-- ============================================================
