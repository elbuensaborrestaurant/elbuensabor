# WEB_Go — Panel de El Buen Sabor

Aplicación web de administración implementada con Go (`net/http` y
`html/template`) y JavaScript/CSS nativos en el navegador. Go renderiza la
interfaz y actúa como proxy de `API_Restaurant`, manteniendo las llamadas de API
en el mismo origen y evitando publicar las credenciales de PostgreSQL.

## Funcionalidades

- Inicio de sesión y validación del perfil del personal con la API Go.
- Cierre de sesión y recuperación de sesiones existentes.
- Centro de mando con conexión, versión, establecimiento y conteo del menú.
- Consulta de datos del establecimiento.
- Gestión CRUD de categorías del menú con confirmación para retirarlas.
- Mensajes de error explícitos si la API no está disponible.

## Ejecución

Inicia PostgreSQL y la API Go (`API_Restaurant`) en el puerto 8080. Después:

```bash
cd WEB_Go
go run .
```

Abre <http://127.0.0.1:5502>. El servidor web Go reenvía las rutas de API a
`http://127.0.0.1:8080` por defecto.

Variables opcionales:

- `API_URL`: URL de API_Restaurant (predeterminada: `http://127.0.0.1:8080`).
- `WEB_ADDR`: dirección de escucha (predeterminada: `127.0.0.1:5502`).
