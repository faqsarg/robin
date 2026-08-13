package db

import (
	"context"
	"database/sql"
	"fmt"

	_ "github.com/jackc/pgx/v5/stdlib"
)

var seedQuotes = []string{
	"An unmonitored server is just a rumor that everything's fine.",
	"'Works on my machine' is DevOps for 'I want my money back'.",
	"There is no cloud, it's just someone else's computer.",
	"If it's not in IaC, sooner or later it gets lost in a click.",
	"YAML: where one extra space ruins your Friday.",
	"The best CI/CD pipeline is the one that doesn't wake you up at 3am.",
	"'Just a tiny change' — famous last words.",
	"A hardcoded secret is a love letter to attackers.",
	"The pipeline is green, but is it actually working?",
}

func Connect(dsn string) (*sql.DB, error) {
	db, err := sql.Open("pgx", dsn)
	if err != nil {
		return nil, fmt.Errorf("opening db: %w", err)
	}
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("pinging db: %w", err)
	}
	return db, nil
}

func Migrate(ctx context.Context, db *sql.DB) error {
	_, err := db.ExecContext(ctx, `
		CREATE TABLE IF NOT EXISTS quotes (
			id SERIAL PRIMARY KEY,
			text TEXT NOT NULL
		)
	`)
	if err != nil {
		return fmt.Errorf("creating quotes table: %w", err)
	}

	var count int
	if err := db.QueryRowContext(ctx, `SELECT COUNT(*) FROM quotes`).Scan(&count); err != nil {
		return fmt.Errorf("counting quotes: %w", err)
	}
	if count > 0 {
		return nil
	}

	for _, q := range seedQuotes {
		if _, err := db.ExecContext(ctx, `INSERT INTO quotes (text) VALUES ($1)`, q); err != nil {
			return fmt.Errorf("seeding quote: %w", err)
		}
	}
	return nil
}

func RandomQuote(ctx context.Context, db *sql.DB) (string, error) {
	var text string
	err := db.QueryRowContext(ctx, `SELECT text FROM quotes ORDER BY random() LIMIT 1`).Scan(&text)
	if err != nil {
		return "", fmt.Errorf("fetching random quote: %w", err)
	}
	return text, nil
}
