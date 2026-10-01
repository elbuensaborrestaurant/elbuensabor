from fastapi import APIRouter
from app.core.response import success_response, error_response
from app.modules.configmod.repository import ConfigRepository

router = APIRouter(prefix="/api/v1/config", tags=["Config"])
repo = ConfigRepository()

@router.get("/establecimiento")
async def get_establecimiento():
    try:
        est = await repo.get_establecimiento()
        if not est:
            return error_response(
                code="NOT_FOUND",
                message="No se ha configurado la información del establecimiento",
                status_code=404,
            )
        return success_response(data=est.model_dump(mode="json"))
    except Exception as e:
        return error_response(
            code="INTERNAL_SERVER_ERROR",
            message=str(e),
            status_code=500,
        )
