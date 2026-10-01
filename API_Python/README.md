# API Restaurant — "El Buen Sabor" (Versión Python)

Implementación equivalente en Python (FastAPI + asyncpg) de la API REST para el restaurante "El Buen Sabor" / "Sabor Urbano", con exactamente los mismos endpoints, formato de respuestas JSON (*Envelope pattern*), variables de entorno y soporte de base de datos PostgreSQL que la versión en Go ([API_Restaurant/](../API_Restaurant)).

## Requisitos

- Python 3.10+ (instalado: 3.13)
- PostgreSQL 14+ con el esquema `elbuensabor_schema.sql` cargado

## Estructura del Proyecto

```
API_Python/
├── app/
│   ├── main.py                    # Aplicación FastAPI, lifespan y registro de routers
│   ├── core/
│   │   ├── config.py              # Variables de entorno y configuración
│   │   └── response.py            # Formato estándar de respuestas (success, data, error)
│   ├── platform/
│   │   └── db.py                  # Pool asíncrono de conexiones (asyncpg)
│   └── modules/
│       ├── configmod/             # Módulo de configuración (GET /api/v1/config/establecimiento)
│       └── menu/                  # Módulo de menú (CRUD /api/v1/menu/categorias)
├── .env.example                   # Plantilla de variables de entorno
├── .gitignore
├── Makefile                       # Tareas comunes (venv, install, run, dev)
├── requirements.txt               # Dependencias de producción
└── README.md
```

## Instalación y Puesta en Marcha

### 1. Configurar entorno virtual e instalar dependencias

```bash
cd /home/evazquez/Desarrollo/elbuensabor/API_Python

# Crear el entorno virtual
python3 -m venv .venv

# Instalar dependencias
./.venv/bin/pip install --upgrade pip
./.venv/bin/pip install -r requirements.txt
```

### 2. Configurar variables de entorno

```bash
cp .env.example .env
# Editar .env con la contraseña real de PostgreSQL si difiere
```

### 3. Ejecutar la API

```bash
# Modo ejecución estándar
./.venv/bin/python -m app.main

# O en modo desarrollo con recarga automática:
make dev
```

La API quedará escuchando en `http://0.0.0.0:8000` (el puerto 8080 queda reservado para la versión en Go).

## Documentación Interactiva Swagger / OpenAPI

FastAPI genera automáticamente documentación interactiva accesible desde el navegador:
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

## Endpoints Disponibles

| Método | Endpoint | Descripción |
|---|---|---|
| `GET` | `/health` | Health check del servidor y ping a PostgreSQL |
| `GET` | `/api/v1/version` | Versión de la API |
| `GET` | `/api/v1/config/establecimiento` | Configuración del restaurante |
| `GET` | `/api/v1/menu/categorias` | Lista categorías activas del menú |
| `GET` | `/api/v1/menu/categorias/{id}` | Detalle de una categoría por ID |
| `POST` | `/api/v1/menu/categorias` | Crear una nueva categoría |
| `PUT` | `/api/v1/menu/categorias/{id}` | Actualizar una categoría existente |
| `DELETE`| `/api/v1/menu/categorias/{id}`| Borrado lógico (*soft delete*) de categoría |
