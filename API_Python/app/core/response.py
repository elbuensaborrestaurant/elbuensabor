from typing import Any, Optional
from fastapi.responses import JSONResponse

def success_response(data: Any = None, meta: Optional[Any] = None, status_code: int = 200) -> JSONResponse:
    content: dict[str, Any] = {"success": True, "data": data}
    if meta is not None:
        content["meta"] = meta
    return JSONResponse(status_code=status_code, content=content)

def error_response(code: str, message: str, status_code: int = 400) -> JSONResponse:
    content = {
        "success": False,
        "error": {
            "code": code,
            "message": message,
        },
    }
    return JSONResponse(status_code=status_code, content=content)

#Cambio para agregar las mesas, René

#Cambio para agregar las pedidos a domicilio, Diego