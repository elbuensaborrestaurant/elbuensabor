from typing import Optional
from app.platform.db import get_pool
from app.modules.configmod.models import EstablecimientoResponse

class ConfigRepository:
    async def get_establecimiento(self) -> Optional[EstablecimientoResponse]:
        query = """
            SELECT
                id::text,
                nombre,
                slogan,
                logo_url,
                direccion,
                telefono,
                email,
                rfc,
                razon_social,
                regimen_fiscal,
                codigo_postal_fiscal,
                wifi_ssid,
                timezone,
                moneda,
                porcentaje_iva::float,
                mensaje_ticket,
                created_at,
                updated_at
            FROM config.establecimiento
            LIMIT 1;
        """
        pool = get_pool()
        async with pool.acquire() as conn:
            row = await conn.fetchrow(query)
            if not row:
                return None
            return EstablecimientoResponse(**dict(row))
