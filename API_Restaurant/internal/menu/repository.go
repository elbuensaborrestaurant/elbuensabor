package menu

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrNotFound = errors.New("categoria no encontrada")
)

type Repository struct {
	pool *pgxpool.Pool
}

func NewRepository(pool *pgxpool.Pool) *Repository {
	return &Repository{pool: pool}
}

func (r *Repository) ListCategoriasActivas(ctx context.Context) ([]Categoria, error) {
	query := `
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
	`

	rows, err := r.pool.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("consultando menu.categorias: %w", err)
	}
	defer rows.Close()

	var categorias []Categoria
	for rows.Next() {
		var c Categoria
		if err := rows.Scan(
			&c.ID,
			&c.Nombre,
			&c.Descripcion,
			&c.ImagenURL,
			&c.ColorHex,
			&c.Icono,
			&c.Orden,
		); err != nil {
			return nil, fmt.Errorf("escaneando categoria: %w", err)
		}
		categorias = append(categorias, c)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterando categorias: %w", err)
	}

	if categorias == nil {
		categorias = []Categoria{}
	}

	return categorias, nil
}

func (r *Repository) GetCategoriaByID(ctx context.Context, id string) (*Categoria, error) {
	query := `
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
		WHERE id = $1 AND deleted_at IS NULL;
	`

	var c Categoria
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&c.ID,
		&c.Nombre,
		&c.Descripcion,
		&c.ImagenURL,
		&c.ColorHex,
		&c.Icono,
		&c.Orden,
		&c.DisponibleDesde,
		&c.DisponibleHasta,
		&c.Estado,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("obteniendo categoria por id: %w", err)
	}

	return &c, nil
}

func (r *Repository) CreateCategoria(ctx context.Context, input CreateCategoriaInput) (*Categoria, error) {
	estado := "activo"
	if input.Estado != nil && *input.Estado != "" {
		estado = *input.Estado
	}

	query := `
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
			$1, $2, $3, $4, $5, $6, $7, $8, $9::public.estado_general
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
	`

	var c Categoria
	err := r.pool.QueryRow(
		ctx,
		query,
		input.Nombre,
		input.Descripcion,
		input.ImagenURL,
		input.ColorHex,
		input.Icono,
		input.Orden,
		input.DisponibleDesde,
		input.DisponibleHasta,
		estado,
	).Scan(
		&c.ID,
		&c.Nombre,
		&c.Descripcion,
		&c.ImagenURL,
		&c.ColorHex,
		&c.Icono,
		&c.Orden,
		&c.DisponibleDesde,
		&c.DisponibleHasta,
		&c.Estado,
	)
	if err != nil {
		return nil, fmt.Errorf("insertando categoria: %w", err)
	}

	return &c, nil
}

func (r *Repository) UpdateCategoria(ctx context.Context, id string, input UpdateCategoriaInput) (*Categoria, error) {
	estado := "activo"
	if input.Estado != nil && *input.Estado != "" {
		estado = *input.Estado
	}

	query := `
		UPDATE menu.categorias
		SET
			nombre = $1,
			descripcion = $2,
			imagen_url = $3,
			color_hex = $4,
			icono = $5,
			orden = $6,
			disponible_desde = $7,
			disponible_hasta = $8,
			estado = $9::public.estado_general
		WHERE id = $10 AND deleted_at IS NULL
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
	`

	var c Categoria
	err := r.pool.QueryRow(
		ctx,
		query,
		input.Nombre,
		input.Descripcion,
		input.ImagenURL,
		input.ColorHex,
		input.Icono,
		input.Orden,
		input.DisponibleDesde,
		input.DisponibleHasta,
		estado,
		id,
	).Scan(
		&c.ID,
		&c.Nombre,
		&c.Descripcion,
		&c.ImagenURL,
		&c.ColorHex,
		&c.Icono,
		&c.Orden,
		&c.DisponibleDesde,
		&c.DisponibleHasta,
		&c.Estado,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("actualizando categoria: %w", err)
	}

	return &c, nil
}

func (r *Repository) DeleteCategoria(ctx context.Context, id string) error {
	query := `
		UPDATE menu.categorias
		SET deleted_at = NOW(), estado = 'inactivo'
		WHERE id = $1 AND deleted_at IS NULL;
	`

	tag, err := r.pool.Exec(ctx, query, id)
	if err != nil {
		return fmt.Errorf("eliminando categoria: %w", err)
	}

	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}

	return nil
}
