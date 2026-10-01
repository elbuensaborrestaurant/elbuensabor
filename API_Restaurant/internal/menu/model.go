package menu

// Categoria representa una categoría de platillos/bebidas en menu.categorias.
type Categoria struct {
	ID              string  `json:"id"`
	Nombre          string  `json:"nombre"`
	Descripcion     *string `json:"descripcion"`
	ImagenURL       *string `json:"imagen_url"`
	ColorHex        *string `json:"color_hex"`
	Icono           *string `json:"icono"`
	Orden           int16   `json:"orden"`
	DisponibleDesde *string `json:"disponible_desde,omitempty"`
	DisponibleHasta *string `json:"disponible_hasta,omitempty"`
	Estado          string  `json:"estado,omitempty"`
}

// CreateCategoriaInput datos necesarios para crear una nueva categoría.
type CreateCategoriaInput struct {
	Nombre          string  `json:"nombre"`
	Descripcion     *string `json:"descripcion"`
	ImagenURL       *string `json:"imagen_url"`
	ColorHex        *string `json:"color_hex"`
	Icono           *string `json:"icono"`
	Orden           int16   `json:"orden"`
	DisponibleDesde *string `json:"disponible_desde"`
	DisponibleHasta *string `json:"disponible_hasta"`
	Estado          *string `json:"estado"`
}

// UpdateCategoriaInput datos para actualizar una categoría existente.
type UpdateCategoriaInput struct {
	Nombre          string  `json:"nombre"`
	Descripcion     *string `json:"descripcion"`
	ImagenURL       *string `json:"imagen_url"`
	ColorHex        *string `json:"color_hex"`
	Icono           *string `json:"icono"`
	Orden           int16   `json:"orden"`
	DisponibleDesde *string `json:"disponible_desde"`
	DisponibleHasta *string `json:"disponible_hasta"`
	Estado          *string `json:"estado"`
}
