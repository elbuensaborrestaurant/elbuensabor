# WEB_Python — Panel de El Buen Sabor

Frontend administrativo escrito con HTML5, CSS y JavaScript sin frameworks. Un
servidor ligero de la biblioteca estándar de Python sirve la interfaz y reenvía
las solicitudes `/api/v1` a `API_Python`; no requiere instalar dependencias web
ni expone las credenciales de PostgreSQL al navegador.

## Funcionalidades

- Inicio de sesión contra `personal.usuarios` a través de `POST /api/v1/auth/login`.
- Perfil de la sesión y cierre de sesión mediante `/api/v1/auth/me` y `/logout`.
- Resumen del restaurante con estado/versión de la API y categorías activas.
- Consulta de la configuración del establecimiento.
- Gestión CRUD de categorías del menú (listar, ver, crear, editar y eliminar).
- Manejo de expiración de sesión y mensajes de error de la API.

## Ejecución

Primero inicia PostgreSQL y la API Python desde `API_Python`, con sus variables
de conexión configuradas:

```bash
cd API_Python
./.venv/bin/python -m app.main
```

En otra terminal:

```bash
cd WEB_Python
python3 server.py
```

Abre <http://127.0.0.1:5501>. El usuario y la contraseña se validan en la tabla
`personal.usuarios`; el navegador solo recibe un token de sesión.

Variables opcionales del servidor web:

- `API_URL`: URL base de API_Python (predeterminada: `http://127.0.0.1:8000`).
- `WEB_HOST` y `WEB_PORT`: dirección de escucha (predeterminadas: `127.0.0.1:5501`).
