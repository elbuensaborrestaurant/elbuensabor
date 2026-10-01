from datetime import datetime
from typing import Optional
from pydantic import BaseModel

class EstablecimientoResponse(BaseModel):
    id: str
    nombre: str
    slogan: Optional[str] = None
    logo_url: Optional[str] = None
    direccion: Optional[str] = None
    telefono: Optional[str] = None
    email: Optional[str] = None
    rfc: Optional[str] = None
    razon_social: Optional[str] = None
    regimen_fiscal: Optional[str] = None
    codigo_postal_fiscal: Optional[str] = None
    wifi_ssid: Optional[str] = None
    timezone: str = "America/Mexico_City"
    moneda: str = "MXN"
    porcentaje_iva: float = 16.00
    mensaje_ticket: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
