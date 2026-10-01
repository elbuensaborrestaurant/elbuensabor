import os
from dataclasses import dataclass
from dotenv import load_dotenv

# Carga variables de entorno desde .env si existe
load_dotenv()

@dataclass(frozen=True)
class Config:
    app_env: str = os.getenv("APP_ENV", "development")
    log_level: str = os.getenv("LOG_LEVEL", "info")

    db_host: str = os.getenv("DB_HOST", "localhost")
    db_port: int = int(os.getenv("DB_PORT", "5432"))
    db_name: str = os.getenv("DB_NAME", "elbuensabor")
    db_user: str = os.getenv("DB_USER", "api_user")
    db_password: str = os.getenv("DB_PASSWORD", "")
    db_pool_max: int = int(os.getenv("DB_POOL_MAX", "10"))
    db_pool_min: int = int(os.getenv("DB_POOL_MIN", "2"))

    server_host: str = os.getenv("SERVER_HOST", "0.0.0.0")
    server_port: int = int(os.getenv("SERVER_PORT", "8080"))

    jwt_secret: str = os.getenv("JWT_SECRET", "")
    jwt_expiry: str = os.getenv("JWT_EXPIRY", "8h")
    jwt_pin_expiry: str = os.getenv("JWT_PIN_EXPIRY", "2h")

config = Config()
