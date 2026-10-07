import hashlib
import secrets
from datetime import datetime, timedelta, timezone

import bcrypt

from app.platform.db import get_pool


class AuthRepository:
    async def login(self, username: str, password: str, expiry: timedelta) -> dict | None:
        pool = get_pool()
        async with pool.acquire() as conn:
            async with conn.transaction():
                row = await conn.fetchrow(
                    """
                    SELECT u.id::text, u.nombre, u.apellido, u.email, u.username,
                           u.password_hash, r.id::text AS rol_id, r.nombre AS rol_nombre,
                           r.tipo::text AS rol_tipo
                    FROM personal.usuarios AS u
                    JOIN personal.roles AS r ON r.id = u.rol_id
                    WHERE u.username = $1
                      AND u.estado = 'activo'
                      AND u.deleted_at IS NULL
                      AND r.estado = 'activo'
                    """,
                    username,
                )
                if row is None:
                    return None

                try:
                    valid_password = bcrypt.checkpw(
                        password.encode("utf-8"),
                        row["password_hash"].encode("utf-8"),
                    )
                except ValueError:
                    valid_password = False
                if not valid_password:
                    return None

                token = secrets.token_urlsafe(32)
                expires_at = datetime.now(timezone.utc) + expiry
                await conn.execute(
                    """
                    INSERT INTO personal.sesiones_usuario (usuario_id, token, expira_en)
                    VALUES ($1::uuid, $2, $3)
                    """,
                    row["id"],
                    hashlib.sha256(token.encode("ascii")).hexdigest(),
                    expires_at,
                )
                last_login = await conn.fetchval(
                    "UPDATE personal.usuarios SET ultimo_login = NOW() WHERE id = $1::uuid RETURNING ultimo_login",
                    row["id"],
                )
                return {
                    "token": token,
                    "expires_at": expires_at.isoformat(),
                    "usuario": self._user_from_row(row, last_login),
                }

    async def get_session_user(self, token: str) -> dict | None:
        pool = get_pool()
        async with pool.acquire() as conn:
            row = await conn.fetchrow(
                """
                SELECT u.id::text, u.nombre, u.apellido, u.email, u.username,
                       u.ultimo_login, r.id::text AS rol_id, r.nombre AS rol_nombre,
                       r.tipo::text AS rol_tipo
                FROM personal.sesiones_usuario AS s
                JOIN personal.usuarios AS u ON u.id = s.usuario_id
                JOIN personal.roles AS r ON r.id = u.rol_id
                WHERE s.token = $1
                  AND s.expira_en > NOW()
                  AND u.estado = 'activo'
                  AND u.deleted_at IS NULL
                  AND r.estado = 'activo'
                """,
                hashlib.sha256(token.encode("ascii")).hexdigest(),
            )
            return self._user_from_row(row) if row else None

    async def logout(self, token: str) -> None:
        pool = get_pool()
        async with pool.acquire() as conn:
            await conn.execute(
                "DELETE FROM personal.sesiones_usuario WHERE token = $1",
                hashlib.sha256(token.encode("ascii")).hexdigest(),
            )

    @staticmethod
    def _user_from_row(row, last_login=None) -> dict:
        login_date = last_login or row.get("ultimo_login")
        return {
            "id": row["id"],
            "nombre": row["nombre"],
            "apellido": row["apellido"],
            "email": row["email"],
            "username": row["username"],
            "rol": {
                "id": row["rol_id"],
                "nombre": row["rol_nombre"],
                "tipo": row["rol_tipo"],
            },
            "ultimo_login": login_date.isoformat() if login_date else None,
        }
