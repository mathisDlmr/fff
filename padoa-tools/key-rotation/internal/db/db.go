package db

import (
	"context"
	"database/sql"

	_ "github.com/lib/pq"

	"key-rotation/internal/model"
)

func Connect(postgresURL string) (*sql.DB, error) {
	db, err := sql.Open("postgres", postgresURL)
	if err != nil {
		return nil, err
	}
	return db, db.Ping()
}

func FetchPendingBatch(ctx context.Context, db *sql.DB, batchSize int) ([]model.File, error) {
	query := `
		SELECT f.file_id, f.s3_name
		FROM file f
		JOIN file_encryption fe ON f.file_id = fe.file_id
		WHERE fe.status = 'pending'
		ORDER BY f.file_id
		LIMIT $1
		FOR UPDATE SKIP LOCKED
	`

	rows, err := db.QueryContext(ctx, query, batchSize)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var files []model.File
	for rows.Next() {
		var f model.File
		if err := rows.Scan(&f.FileID, &f.S3Name); err != nil {
			return nil, err
		}
		files = append(files, f)
	}
	return files, nil
}

func UpdateStatus(ctx context.Context, db *sql.DB, fileID string, status string, incrementRetry bool) error {
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	var updateQuery string
	if incrementRetry {
		updateQuery = `
			UPDATE file_encryption
			SET status = $1, retries = retries + 1
			WHERE file_id = $2
		`
	} else {
		updateQuery = `
			UPDATE file_encryption
			SET status = $1
			WHERE file_id = $2
		`
	}

	_, err = tx.ExecContext(ctx, updateQuery, status, fileID)
	if err != nil {
		return err
	}

	return tx.Commit()
}
