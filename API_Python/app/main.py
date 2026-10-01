import logging
import time
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.config import config
from app.core.response import success_response, error_response
from app.platform.db import init_pool, close_pool, ping
from app.modules.configmod.router import router as config_router
from app.modules.menu.router import router as menu_router

# Configuración de logs estructurados
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger("api_restaurant")

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Inicio: inicializar pool de PostgreSQL
    logger.info("Iniciando pool de conexiones PostgreSQL...")
    try:
        await init_pool()
        logger.info("Conexión con PostgreSQL establecida correctamente.")
    except Exception as e:
        logger.error(f"No se pudo conectar a la base de datos: {e}")
        raise e
    yield
    # Cierre: graceful shutdown del pool
    logger.info("Apagando servidor: cerrando pool de PostgreSQL...")
    await close_pool()
    logger.info("Pool cerrado ordenadamente.")

app = FastAPI(
    title="El Buen Sabor API (Python)",
    version="0.1.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# Middleware de logging de peticiones (equivalente a withLogging en Go)
@app.middleware("http")
async def logging_middleware(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    duration_ms = int((time.time() - start) * 1000)
    logger.info(
        f"request method={request.method} path={request.url.path} "
        f"status={response.status_code} duration_ms={duration_ms}"
    )
    return response

# Manejador uniforme de errores 404/HTTP
@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    code = "NOT_FOUND" if exc.status_code == 404 else "HTTP_ERROR"
    return error_response(code=code, message=str(exc.detail), status_code=exc.status_code)

# Manejador uniforme de validación de Pydantic
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    errors = exc.errors()
    msg = "; ".join([f"{'.'.join(str(loc) for loc in err['loc'])}: {err['msg']}" for err in errors])
    return error_response(code="VALIDATION_ERROR", message=msg, status_code=422)

# Endpoints base del sistema
@app.get("/health")
async def health_check():
    try:
        await ping()
        return success_response(data={"status": "ok"})
    except Exception as e:
        return error_response(
            code="DB_UNAVAILABLE",
            message=str(e),
            status_code=503,
        )

@app.get("/api/v1/version")
async def get_version():
    return success_response(data={"version": "0.1.0"})

# Registro de routers modulares
app.include_router(config_router)
app.include_router(menu_router)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host=config.server_host,
        port=config.server_port,
        reload=(config.app_env == "development"),
        log_level=config.log_level.lower(),
    )
