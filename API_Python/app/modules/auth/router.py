import re
from datetime import timedelta

from fastapi import APIRouter, Request, Response

from app.core.config import config
from app.core.response import error_response, success_response
from app.modules.auth.models import LoginInput
from app.modules.auth.repository import AuthRepository

router = APIRouter(prefix="/api/v1/auth", tags=["Autenticación"])
repo = AuthRepository()
_DURATION_PART = re.compile(r"(\d+(?:\.\d+)?)(ns|us|µs|ms|s|m|h)")
_DURATION_SECONDS = {"ns": 1e-9, "us": 1e-6, "µs": 1e-6, "ms": 1e-3, "s": 1, "m": 60, "h": 3600}


def _session_expiry() -> timedelta:
    value = config.jwt_expiry.strip()
    matches = list(_DURATION_PART.finditer(value))
    if not matches or "".join(match.group(0) for match in matches) != value:
        raise ValueError("JWT_EXPIRY debe ser una duración válida, por ejemplo 8h.")
    seconds = sum(float(match.group(1)) * _DURATION_SECONDS[match.group(2)] for match in matches)
    if seconds <= 0:
        raise ValueError("JWT_EXPIRY debe ser mayor que cero.")
    return timedelta(seconds=seconds)


def _bearer_token(request: Request) -> str | None:
    scheme, separator, token = request.headers.get("authorization", "").partition(" ")
    if not separator or scheme.lower() != "bearer" or not token.strip():
        return None
    return token.strip()


@router.post("/login")
async def login(input_data: LoginInput):
    session = await repo.login(input_data.username.strip(), input_data.password, _session_expiry())
    if session is None:
        return error_response("INVALID_CREDENTIALS", "Usuario o contraseña incorrectos.", 401)
    return success_response(data=session)


@router.get("/me")
async def get_current_user(request: Request):
    token = _bearer_token(request)
    user = await repo.get_session_user(token) if token else None
    if user is None:
        return error_response("UNAUTHORIZED", "La sesión no es válida o ha expirado.", 401)
    return success_response(data=user)


@router.post("/logout")
async def logout(request: Request):
    token = _bearer_token(request)
    if token:
        await repo.logout(token)
    return Response(status_code=204)
