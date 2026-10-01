from fastapi import APIRouter
from app.core.response import success_response, error_response
from app.modules.menu.models import CreateCategoriaInput, UpdateCategoriaInput
from app.modules.menu.repository import MenuRepository

router = APIRouter(prefix="/api/v1/menu", tags=["Menu"])
repo = MenuRepository()

@router.get("/categorias")
async def list_categorias():
    try:
        items = await repo.list_categorias_activas()
        return success_response(data=[item.model_dump() for item in items])
    except Exception as e:
        return error_response(
            code="INTERNAL_SERVER_ERROR",
            message=str(e),
            status_code=500,
        )

@router.get("/categorias/{categoria_id}")
async def get_categoria(categoria_id: str):
    if not categoria_id.strip():
        return error_response(
            code="BAD_REQUEST",
            message="El ID de la categoría es requerido",
            status_code=400,
        )
    try:
        cat = await repo.get_categoria_by_id(categoria_id)
        if not cat:
            return error_response(
                code="NOT_FOUND",
                message="La categoría solicitada no existe",
                status_code=404,
            )
        return success_response(data=cat.model_dump())
    except Exception as e:
        return error_response(
            code="INTERNAL_SERVER_ERROR",
            message=str(e),
            status_code=500,
        )

@router.post("/categorias", status_code=201)
async def create_categoria(input_data: CreateCategoriaInput):
    if not input_data.nombre or not input_data.nombre.strip():
        return error_response(
            code="VALIDATION_ERROR",
            message="El campo 'nombre' es obligatorio",
            status_code=422,
        )
    try:
        created = await repo.create_categoria(input_data)
        return success_response(data=created.model_dump(), status_code=201)
    except Exception as e:
        return error_response(
            code="INTERNAL_SERVER_ERROR",
            message=str(e),
            status_code=500,
        )

@router.put("/categorias/{categoria_id}")
async def update_categoria(categoria_id: str, input_data: UpdateCategoriaInput):
    if not categoria_id.strip():
        return error_response(
            code="BAD_REQUEST",
            message="El ID de la categoría es requerido",
            status_code=400,
        )
    if not input_data.nombre or not input_data.nombre.strip():
        return error_response(
            code="VALIDATION_ERROR",
            message="El campo 'nombre' no puede estar vacío",
            status_code=422,
        )
    try:
        updated = await repo.update_categoria(categoria_id, input_data)
        if not updated:
            return error_response(
                code="NOT_FOUND",
                message="La categoría a actualizar no existe",
                status_code=404,
            )
        return success_response(data=updated.model_dump())
    except Exception as e:
        return error_response(
            code="INTERNAL_SERVER_ERROR",
            message=str(e),
            status_code=500,
        )

@router.delete("/categorias/{categoria_id}")
async def delete_categoria(categoria_id: str):
    if not categoria_id.strip():
        return error_response(
            code="BAD_REQUEST",
            message="El ID de la categoría es requerido",
            status_code=400,
        )
    try:
        deleted = await repo.delete_categoria(categoria_id)
        if not deleted:
            return error_response(
                code="NOT_FOUND",
                message="La categoría a eliminar no existe",
                status_code=404,
            )
        return success_response(data={"message": "Categoría eliminada correctamente"})
    except Exception as e:
        return error_response(
            code="INTERNAL_SERVER_ERROR",
            message=str(e),
            status_code=500,
        )
