package configmod

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrNotFound = errors.New("establecimiento no encontrado")

type Repository struct {
	pool *pgxpool.Pool
}

func NewRepository(pool *pgxpool.Pool) *Repository {
	return &Repository{pool: pool}
}

func (r *Repository) GetEstablecimiento(ctx context.Context) (*Establecimiento, error) {
	query := `
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
			porcentaje_iva,
			mensaje_ticket,
			created_at,
			updated_at
		FROM config.establecimiento
		LIMIT 1;
	`

	var e Establecimiento
	err := r.pool.QueryRow(ctx, query).Scan(
		&e.ID,
		&e.Nombre,
		&e.Slogan,
		&e.LogoURL,
		&e.Direccion,
		&e.Telefono,
		&e.Email,
		&e.RFC,
		&e.RazonSocial,
		&e.RegimenFiscal,
		&e.CodigoPostalFiscal,
		&e.WifiSSID,
		&e.Timezone,
		&e.Moneda,
		&e.PorcentajeIVA,
		&e.MensajeTicket,
		&e.CreatedAt,
		&e.UpdatedAt,
	)

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("consultando config.establecimiento: %w", err)
	}

	return &e, nil
}
