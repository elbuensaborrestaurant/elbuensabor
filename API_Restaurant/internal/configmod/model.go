package configmod

import "time"

// Establecimiento representa la entidad del restaurante en la tabla config.establecimiento.
type Establecimiento struct {
	ID                 string    `json:"id"`
	Nombre             string    `json:"nombre"`
	Slogan             *string   `json:"slogan"`
	LogoURL            *string   `json:"logo_url,omitempty"`
	Direccion          *string   `json:"direccion"`
	Telefono           *string   `json:"telefono"`
	Email              *string   `json:"email,omitempty"`
	RFC                *string   `json:"rfc,omitempty"`
	RazonSocial        *string   `json:"razon_social,omitempty"`
	RegimenFiscal      *string   `json:"regimen_fiscal,omitempty"`
	CodigoPostalFiscal *string   `json:"codigo_postal_fiscal,omitempty"`
	WifiSSID           *string   `json:"wifi_ssid"`
	Timezone           string    `json:"timezone"`
	Moneda             string    `json:"moneda"`
	PorcentajeIVA      float64   `json:"porcentaje_iva"`
	MensajeTicket      *string   `json:"mensaje_ticket"`
	CreatedAt          time.Time `json:"created_at,omitempty"`
	UpdatedAt          time.Time `json:"updated_at,omitempty"`
}
