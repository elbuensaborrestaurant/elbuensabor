from typing import Optional
from pydantic import BaseModel, Field

class CategoriaListItem(BaseModel):
    id: str
    nombre: str
    descripcion: Optional[str] = None
    imagen_url: Optional[str] = None
    color_hex: Optional[str] = None
    icono: Optional[str] = None
    orden: int = 0

class CategoriaDetail(BaseModel):
    id: str
    nombre: str
    descripcion: Optional[str] = None
    imagen_url: Optional[str] = None
    color_hex: Optional[str] = None
    icono: Optional[str] = None
    orden: int = 0
    disponible_desde: Optional[str] = None
    disponible_hasta: Optional[str] = None
    estado: str = "activo"

class CreateCategoriaInput(BaseModel):
    nombre: str = Field(..., min_length=1)
    descripcion: Optional[str] = None
    imagen_url: Optional[str] = None
    color_hex: Optional[str] = None
    icono: Optional[str] = None
    orden: int = 0
    disponible_desde: Optional[str] = None
    disponible_hasta: Optional[str] = None
    estado: Optional[str] = "activo"

class UpdateCategoriaInput(BaseModel):
    nombre: str = Field(..., min_length=1)
    descripcion: Optional[str] = None
    imagen_url: Optional[str] = None
    color_hex: Optional[str] = None
    icono: Optional[str] = None
    orden: int = 0
    disponible_desde: Optional[str] = None
    disponible_hasta: Optional[str] = None
    estado: Optional[str] = "activo"
