from typing import Optional
from app.platform.db import get_pool
from app.modules.menu.models import (
    CategoriaListItem,
    CategoriaDetail,
    CreateCategoriaInput,
    UpdateCategoriaInput,
)

class MenuRepository:
    async def list_categorias_activas(self) -> list[CategoriaListItem]:
        query = """
            SELECT
                id::text,
                nombre,
                descripcion,
                imagen_url,
                color_hex,
                icono,
                orden
            FROM menu.categorias
            WHERE estado = 'activo' AND deleted_at IS NULL
            ORDER BY orden ASC, nombre ASC;
        """
        pool = get_pool()
        async with pool.acquire() as conn:
            rows = await conn.fetch(query)
            return [CategoriaListItem(**dict(r)) for r in rows]

    async def get_categoria_by_id(self, categoria_id: str) -> Optional[CategoriaDetail]:
        query = """
            SELECT
                id::text,
                nombre,
                descripcion,
                imagen_url,
                color_hex,
                icono,
                orden,
                disponible_desde::text,
                disponible_hasta::text,
                estado::text
            FROM menu.categorias
            WHERE id = $1::uuid AND deleted_at IS NULL;
        """
        pool = get_pool()
        async with pool.acquire() as conn:
            try:
                row = await conn.fetchrow(query, categoria_id)
            except Exception:
                return None
            if not row:
                return None
            return CategoriaDetail(**dict(row))

    async def create_categoria(self, input_data: CreateCategoriaInput) -> CategoriaDetail:
        estado = input_data.estado or "activo"
        query = """
            INSERT INTO menu.categorias (
                nombre,
                descripcion,
                imagen_url,
                color_hex,
                icono,
                orden,
                disponible_desde,
                disponible_hasta,
                estado
            ) VALUES (
                $1, $2, $3, $4, $5, $6, $7::time, $8::time, $9::public.estado_general
            )
            RETURNING
                id::text,
                nombre,
                descripcion,
                imagen_url,
                color_hex,
                icono,
                orden,
                disponible_desde::text,
                disponible_hasta::text,
                estado::text;
        """
        pool = get_pool()
        async with pool.acquire() as conn:
            row = await conn.fetchrow(
                query,
                input_data.nombre,
                input_data.descripcion,
                input_data.imagen_url,
                input_data.color_hex,
                input_data.icono,
                input_data.orden,
                input_data.disponible_desde,
                input_data.disponible_hasta,
                estado,
            )
            return CategoriaDetail(**dict(row))

    async def update_categoria(
        self, categoria_id: str, input_data: UpdateCategoriaInput
    ) -> Optional[CategoriaDetail]:
        estado = input_data.estado or "activo"
        query = """
            UPDATE menu.categorias
            SET
                nombre = $1,
                descripcion = $2,
                imagen_url = $3,
                color_hex = $4,
                icono = $5,
                orden = $6,
                disponible_desde = $7::time,
                disponible_hasta = $8::time,
                estado = $9::public.estado_general
            WHERE id = $10::uuid AND deleted_at IS NULL
            RETURNING
                id::text,
                nombre,
                descripcion,
                imagen_url,
                color_hex,
                icono,
                orden,
                disponible_desde::text,
                disponible_hasta::text,
                estado::text;
        """
        pool = get_pool()
        async with pool.acquire() as conn:
            try:
                row = await conn.fetchrow(
                    query,
                    input_data.nombre,
                    input_data.descripcion,
                    input_data.imagen_url,
                    input_data.color_hex,
                    input_data.icono,
                    input_data.orden,
                    input_data.disponible_desde,
                    input_data.disponible_hasta,
                    estado,
                    categoria_id,
                )
            except Exception:
                return None
            if not row:
                return None
            return CategoriaDetail(**dict(row))

    async def delete_categoria(self, categoria_id: str) -> bool:
        query = """
            UPDATE menu.categorias
            SET deleted_at = NOW(), estado = 'inactivo'
            WHERE id = $1::uuid AND deleted_at IS NULL;
        """
        pool = get_pool()
        async with pool.acquire() as conn:
            try:
                result = await conn.execute(query, categoria_id)
            except Exception:
                return False
            # result returns "UPDATE <count>"
            count = int(result.split(" ")[-1])
            return count > 0
