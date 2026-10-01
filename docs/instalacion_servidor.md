# Guia de Instalacion — Servidor Linux para API REST "El Buen Sabor"

> Sistema operativo objetivo: Fedora / RHEL / Rocky Linux 9 (tambien compatible con Ubuntu/Debian con ajustes indicados)
> Ultima actualizacion: 2026-09-18

---

## Tabla de Contenido

1. Requisitos del servidor
2. Preparacion del sistema operativo
3. Instalacion de PostgreSQL
4. Configuracion de la base de datos
5. Instalacion de Go
6. Compilacion de la API
7. Configuracion del entorno
8. Registro como servicio systemd
9. Configuracion del firewall
10. Configuracion de red local fija
11. Monitoreo y logs
12. Respaldos automaticos
13. Checklist de verificacion

---

## 1. Requisitos del Servidor

### Minimos recomendados

| Componente | Requerimiento |
|---|---|
| CPU | 2 nucleos (Intel/AMD x86_64 o ARM64) |
| RAM | 2 GB minimo, 4 GB recomendado |
| Almacenamiento | 20 GB SSD (HDD acepta mayor latencia) |
| Red | Interfaz Ethernet o WiFi (preferir Ethernet) |
| Sistema Operativo | Linux 64-bit (Fedora 38+, Ubuntu 22.04+, Debian 12+) |

### Recomendado para restaurante de volumen medio-alto

| Componente | Requerimiento |
|---|---|
| CPU | 4 nucleos |
| RAM | 8 GB |
| Almacenamiento | 60 GB SSD |
| Red | Ethernet Gigabit conectado al switch/router principal |

### Hardware sugerido
- Mini PC: Intel NUC, Beelink Mini, ASUS PN, Raspberry Pi 5 (8GB)
- Puede ser una computadora reutilizada de escritorio o laptop sin pantalla

---

## 2. Preparacion del Sistema Operativo

### Actualizar el sistema

```bash
# Fedora / RHEL / Rocky Linux
sudo dnf update -y

# Ubuntu / Debian
sudo apt update && sudo apt upgrade -y
```

### Instalar herramientas basicas

```bash
# Fedora / RHEL
sudo dnf install -y git curl wget unzip tar nano htop

# Ubuntu / Debian
sudo apt install -y git curl wget unzip tar nano htop
```

### Crear usuario dedicado para la API

```bash
sudo useradd -r -s /bin/false -d /opt/api_restaurant api_restaurant
```

---

## 3. Instalacion de PostgreSQL

### Fedora / RHEL / Rocky Linux

```bash
sudo dnf install -y postgresql-server postgresql-contrib
sudo postgresql-setup --initdb
sudo systemctl enable --now postgresql
```

### Ubuntu / Debian

```bash
sudo apt install -y postgresql postgresql-contrib
sudo systemctl enable --now postgresql
```

### Verificar que PostgreSQL esta corriendo

```bash
sudo systemctl status postgresql
```

Debe mostrar: `Active: active (running)`

---

## 4. Configuracion de la Base de Datos

### Acceder al cliente de PostgreSQL como superusuario

```bash
sudo -u postgres psql
```

### Crear base de datos y usuario de la API

```sql
-- Crear usuario con contrasena segura
CREATE USER api_user WITH PASSWORD 'CambiaEstaContrasena2026!';

-- Crear base de datos
CREATE DATABASE elbuensabor OWNER api_user ENCODING 'UTF8';

-- Otorgar todos los permisos sobre la base de datos
GRANT ALL PRIVILEGES ON DATABASE elbuensabor TO api_user;

-- Salir
\q
```

### Cargar el esquema de la base de datos

```bash
psql -U api_user -d elbuensabor -f /ruta/al/elbuensabor_schema.sql
```

Si el archivo esta en el servidor:

```bash
psql -U api_user -d elbuensabor -f /opt/api_restaurant/migrations/elbuensabor_schema.sql
```

### Verificar que las tablas se crearon

```bash
psql -U api_user -d elbuensabor -c "\dt config.*"
psql -U api_user -d elbuensabor -c "\dt menu.*"
psql -U api_user -d elbuensabor -c "\dt personal.*"
```

### Ajustar autenticacion de PostgreSQL (pg_hba.conf)

Editar el archivo de autenticacion:

```bash
# Fedora/RHEL
sudo nano /var/lib/pgsql/data/pg_hba.conf

# Ubuntu/Debian
sudo nano /etc/postgresql/*/main/pg_hba.conf
```

Buscar las lineas con `local` y `host` y cambiar la autenticacion:

```conf
# Permitir conexion local con usuario y contrasena
local   all             all                                     md5
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
```

Reiniciar PostgreSQL para aplicar cambios:

```bash
sudo systemctl restart postgresql
```

### Verificar conexion con el usuario de la API

```bash
psql -U api_user -d elbuensabor -h localhost -c "SELECT current_database(), current_user;"
```

Debe mostrar: `elbuensabor | api_user`

---

## 5. Instalacion de Go

### Descargar e instalar Go 1.22

```bash
cd /tmp
wget https://go.dev/dl/go1.22.5.linux-amd64.tar.gz

# Extraer e instalar
sudo tar -C /usr/local -xzf go1.22.5.linux-amd64.tar.gz
```

Para ARM64 (Raspberry Pi, Apple Silicon):
```bash
wget https://go.dev/dl/go1.22.5.linux-arm64.tar.gz
sudo tar -C /usr/local -xzf go1.22.5.linux-arm64.tar.gz
```

### Agregar Go al PATH del sistema

```bash
echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/go.sh
source /etc/profile.d/go.sh
```

### Verificar instalacion

```bash
go version
```

Debe mostrar: `go version go1.22.5 linux/amd64`

---

## 6. Compilacion de la API

### Obtener el codigo fuente

Si el codigo esta en el mismo servidor:

```bash
sudo mkdir -p /opt/api_restaurant
sudo chown api_restaurant:api_restaurant /opt/api_restaurant
cd /opt/api_restaurant
```

Si se clona desde un repositorio:

```bash
git clone https://github.com/tu-usuario/API_Restaurant.git /opt/api_restaurant
```

### Compilar el binario

```bash
cd /opt/api_restaurant
go mod download
CGO_ENABLED=0 GOOS=linux go build -o bin/api_restaurant ./cmd/server/
```

Para ARM64:
```bash
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -o bin/api_restaurant ./cmd/server/
```

### Verificar que el binario funciona

```bash
/opt/api_restaurant/bin/api_restaurant --version
```

---

## 7. Configuracion del Entorno

### Crear archivo de configuracion

```bash
sudo cp /opt/api_restaurant/.env.example /etc/api_restaurant.env
sudo nano /etc/api_restaurant.env
```

### Contenido del archivo /etc/api_restaurant.env

```env
# --- Base de Datos PostgreSQL ---
DB_HOST=localhost
DB_PORT=5432
DB_NAME=elbuensabor
DB_USER=api_user
DB_PASSWORD=CambiaEstaContrasena2026!
DB_POOL_MAX=10
DB_POOL_MIN=2

# --- Servidor HTTP ---
SERVER_HOST=0.0.0.0
SERVER_PORT=8080
SERVER_READ_TIMEOUT=15s
SERVER_WRITE_TIMEOUT=15s
SERVER_IDLE_TIMEOUT=60s

# --- JWT ---
# Generar con: openssl rand -base64 64
JWT_SECRET=TuClaveSecretaGeneradaAleatoriamente512Bits
JWT_EXPIRY=8h
JWT_PIN_EXPIRY=2h

# --- Aplicacion ---
APP_ENV=production
LOG_LEVEL=info
```

### Asegurar permisos del archivo de configuracion

```bash
sudo chmod 600 /etc/api_restaurant.env
sudo chown root:root /etc/api_restaurant.env
```

> Importante: El archivo contiene contrasenas sensibles. Solo root debe poder leerlo.

### Generar JWT_SECRET seguro

```bash
openssl rand -base64 64
```

Copiar el resultado y pegarlo como valor de `JWT_SECRET` en el archivo `.env`.

---

## 8. Registro como Servicio systemd

### Crear el archivo de unidad del servicio

```bash
sudo nano /etc/systemd/system/api_restaurant.service
```

### Contenido del archivo api_restaurant.service

```ini
[Unit]
Description=El Buen Sabor - API REST Go
Documentation=https://192.168.1.100/docs
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=api_restaurant
Group=api_restaurant
WorkingDirectory=/opt/api_restaurant
EnvironmentFile=/etc/api_restaurant.env
ExecStart=/opt/api_restaurant/bin/api_restaurant
Restart=on-failure
RestartSec=5s

# Limites de seguridad
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/opt/api_restaurant/logs
PrivateTmp=yes

# Logs
StandardOutput=journal
StandardError=journal
SyslogIdentifier=api_restaurant

[Install]
WantedBy=multi-user.target
```

### Crear carpeta de logs

```bash
sudo mkdir -p /opt/api_restaurant/logs
sudo chown api_restaurant:api_restaurant /opt/api_restaurant/logs
```

### Habilitar e iniciar el servicio

```bash
# Recargar configuracion de systemd
sudo systemctl daemon-reload

# Habilitar el servicio para que inicie automaticamente con el sistema
sudo systemctl enable api_restaurant

# Iniciar el servicio
sudo systemctl start api_restaurant

# Verificar estado
sudo systemctl status api_restaurant
```

Debe mostrar: `Active: active (running)`

---

## 9. Configuracion del Firewall

### Fedora / RHEL / Rocky Linux (firewalld)

```bash
# Abrir el puerto 8080 en la zona de confianza local
sudo firewall-cmd --permanent --zone=public --add-port=8080/tcp

# Aplicar cambios
sudo firewall-cmd --reload

# Verificar
sudo firewall-cmd --list-ports
```

### Ubuntu / Debian (ufw)

```bash
sudo ufw allow 8080/tcp
sudo ufw reload
sudo ufw status
```

### Verificar desde otro dispositivo en la red

Desde cualquier celular o computadora conectada al WiFi del restaurante:

```bash
curl http://192.168.1.100:8080/api/v1/menu/categorias
```

Debe responder con el JSON del menu.

---

## 10. Configuracion de Red Local Fija

Es fundamental que el servidor siempre tenga la misma IP en la red local para que:
- Los clientes QR siempre encuentren la API
- Las pantallas KDS siempre se conecten
- Los dispositivos del personal no fallen

### Opcion A: IP fija en el router (Recomendada)

1. Acceder al panel del router local (generalmente `192.168.1.1` o `192.168.0.1`)
2. Ir a la seccion **DHCP > Reservacion de IP** o **Static DHCP**
3. Buscar la MAC address del servidor: `ip link show`
4. Asignar una IP fija, por ejemplo: `192.168.1.100`

### Opcion B: IP estatica en el servidor (Red cableada)

Editar la conexion de red:

```bash
# Listar conexiones disponibles
nmcli connection show

# Configurar IP estatica (ajustar nombre de interfaz y IPs segun la red)
sudo nmcli connection modify "Wired connection 1" \
  ipv4.method manual \
  ipv4.addresses "192.168.1.100/24" \
  ipv4.gateway "192.168.1.1" \
  ipv4.dns "192.168.1.1,8.8.8.8"

# Aplicar cambios
sudo nmcli connection up "Wired connection 1"
```

Verificar la IP asignada:

```bash
ip addr show
```

### Actualizar URL del QR

Una vez definida la IP del servidor, actualizar la URL base de los QR codes. La columna `url_destino` en `operaciones.qr_codes` se genera como:

```
/menu?mesa=<token>
```

La PWA del cliente debera estar configurada para apuntar a:

```
http://192.168.1.100:8080
```

---

## 11. Monitoreo y Logs

### Ver logs en tiempo real

```bash
sudo journalctl -u api_restaurant -f
```

### Ver ultimas 100 lineas de log

```bash
sudo journalctl -u api_restaurant -n 100
```

### Ver logs de una fecha especifica

```bash
sudo journalctl -u api_restaurant --since "2026-09-18 08:00:00" --until "2026-09-18 23:59:59"
```

### Verificar estado del servicio

```bash
sudo systemctl status api_restaurant
```

### Reiniciar la API (despues de actualizacion)

```bash
sudo systemctl restart api_restaurant
```

### Ver uso de recursos

```bash
# Uso de CPU y RAM en tiempo real
htop

# Uso especifico del proceso Go
ps aux | grep api_restaurant
```

### Monitorear PostgreSQL

```bash
# Conexiones activas a la base de datos
sudo -u postgres psql -c "SELECT count(*) FROM pg_stat_activity WHERE datname = 'elbuensabor';"

# Estado del servidor PostgreSQL
sudo systemctl status postgresql
```

---

## 12. Respaldos Automaticos

### Script de respaldo de base de datos

```bash
sudo nano /opt/api_restaurant/scripts/backup_db.sh
```

Contenido:

```bash
#!/bin/bash
set -e

# Configuracion
DB_NAME="elbuensabor"
DB_USER="api_user"
BACKUP_DIR="/opt/api_restaurant/backups"
FECHA=$(date +%Y%m%d_%H%M%S)
ARCHIVO="$BACKUP_DIR/${DB_NAME}_${FECHA}.sql.gz"
DIAS_RETENER=30

# Crear directorio de respaldos si no existe
mkdir -p "$BACKUP_DIR"

# Ejecutar respaldo comprimido
PGPASSWORD="CambiaEstaContrasena2026!" pg_dump \
  -U "$DB_USER" \
  -h localhost \
  "$DB_NAME" | gzip > "$ARCHIVO"

echo "Respaldo creado: $ARCHIVO"

# Eliminar respaldos mas antiguos que DIAS_RETENER dias
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$DIAS_RETENER -delete

echo "Respaldos antiguos eliminados."
```

```bash
sudo chmod +x /opt/api_restaurant/scripts/backup_db.sh
sudo chown api_restaurant:api_restaurant /opt/api_restaurant/scripts/backup_db.sh
sudo mkdir -p /opt/api_restaurant/backups
sudo chown api_restaurant:api_restaurant /opt/api_restaurant/backups
```

### Programar respaldo automatico con cron

```bash
sudo -u api_restaurant crontab -e
```

Agregar las siguientes lineas:

```cron
# Respaldo completo todos los dias a las 3:00 AM
0 3 * * * /opt/api_restaurant/scripts/backup_db.sh >> /opt/api_restaurant/logs/backup.log 2>&1

# Respaldo adicional al medio dia (12:00 PM)
0 12 * * * /opt/api_restaurant/scripts/backup_db.sh >> /opt/api_restaurant/logs/backup.log 2>&1
```

### Restaurar un respaldo

```bash
# Descomprimir y restaurar
gunzip -c /opt/api_restaurant/backups/elbuensabor_20260918_030000.sql.gz | \
  psql -U api_user -d elbuensabor -h localhost
```

---

## 13. Checklist de Verificacion

Completar esta lista despues de la instalacion:

### Sistema Operativo
- [ ] Sistema actualizado (`dnf update -y` o `apt upgrade -y`)
- [ ] Usuario `api_restaurant` creado sin shell
- [ ] Herramientas basicas instaladas (git, curl, wget)

### PostgreSQL
- [ ] PostgreSQL instalado y corriendo
- [ ] Base de datos `elbuensabor` creada
- [ ] Usuario `api_user` creado con contrasena segura
- [ ] Schema cargado (`elbuensabor_schema.sql` ejecutado sin errores)
- [ ] Conexion verificada con `psql -U api_user -d elbuensabor -h localhost`
- [ ] Datos seed presentes (roles, zonas, unidades de medida)

### Go y API
- [ ] Go 1.22+ instalado (`go version`)
- [ ] Codigo fuente de la API en `/opt/api_restaurant/`
- [ ] Binario compilado en `/opt/api_restaurant/bin/api_restaurant`
- [ ] Archivo `/etc/api_restaurant.env` creado con valores correctos
- [ ] `JWT_SECRET` generado de forma aleatoria y segura
- [ ] `DB_PASSWORD` coincide con la contrasena de PostgreSQL

### Servicio systemd
- [ ] Archivo `/etc/systemd/system/api_restaurant.service` creado
- [ ] `systemctl daemon-reload` ejecutado
- [ ] `systemctl enable api_restaurant` ejecutado
- [ ] `systemctl start api_restaurant` ejecutado
- [ ] `systemctl status api_restaurant` muestra "active (running)"

### Red
- [ ] Puerto 8080 abierto en el firewall
- [ ] IP fija asignada al servidor (via router o configuracion local)
- [ ] API accesible desde celular en la LAN: `curl http://192.168.1.100:8080/api/v1/menu/categorias`

### Respaldos
- [ ] Script `backup_db.sh` creado y con permisos de ejecucion
- [ ] Cron configurado para respaldos automaticos
- [ ] Primer respaldo manual exitoso

### Prueba Final de Extremo a Extremo
- [ ] Login exitoso: `POST /api/v1/auth/login` retorna JWT
- [ ] Menu visible sin autenticacion: `GET /api/v1/menu/categorias`
- [ ] Logs limpios en `journalctl -u api_restaurant`

---

## Comandos de Referencia Rapida

```bash
# Iniciar/detener/reiniciar la API
sudo systemctl start api_restaurant
sudo systemctl stop api_restaurant
sudo systemctl restart api_restaurant

# Ver logs en tiempo real
sudo journalctl -u api_restaurant -f

# Verificar conectividad con la API
curl http://localhost:8080/api/v1/menu/categorias

# Acceder a PostgreSQL como administrador
sudo -u postgres psql

# Acceder a la base de datos como usuario de la API
psql -U api_user -d elbuensabor -h localhost

# Respaldo manual de la base de datos
/opt/api_restaurant/scripts/backup_db.sh

# Ver estado de todos los servicios criticos
sudo systemctl status postgresql api_restaurant

# Compilar y actualizar el binario de la API
cd /opt/api_restaurant
go build -o bin/api_restaurant ./cmd/server/
sudo systemctl restart api_restaurant
```
