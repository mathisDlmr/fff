package worker

import (
	"context"
	"database/sql"
	"log"

	"key-rotation/config"
	"key-rotation/internal/db"
	"key-rotation/internal/model"
	"key-rotation/internal/storage"
)

func ProcessBatch(ctx context.Context, dbClient *sql.DB, cfg *config.Config, batch []model.File, workerID int) error {

	storageClient := storage.NewStorageClient(cfg.StorageAccountName, cfg.ContainerName, cfg.SASToken)

	for _, file := range batch {
		originalName := file.S3Name
		encryptedName := "encrypted_" + originalName

		log.Printf("[Worker %d] Processing file %s", workerID, originalName)

		content, err := storageClient.DownloadBlob(ctx, originalName, cfg.OldEncryptionKey, cfg.OldEncryptionKeyHash, cfg.EncryptionAlgorithm)
		if err != nil {
			log.Printf("[Worker %d]  Failed to download %s: %v", workerID, originalName, err)
			if err2 := db.UpdateStatus(ctx, dbClient, file.FileID, "failed", true); err2 != nil {
				log.Printf("[Worker %d]  Failed to update status for %s: %v", workerID, originalName, err2)
			}
			continue
		}

		err = storageClient.UploadBlob(ctx, encryptedName, content, cfg.NewEncryptionKey, cfg.NewEncryptionKeyHash, cfg.EncryptionAlgorithm)
		if err != nil {
			log.Printf("[Worker %d]  Failed to upload %s: %v", workerID, encryptedName, err)
			if err2 := db.UpdateStatus(ctx, dbClient, file.FileID, "failed", true); err2 != nil {
				log.Printf("[Worker %d] Failed to update status for %s: %v", workerID, originalName, err2)
			}
			continue
		}

		if err := db.UpdateStatus(ctx, dbClient, file.FileID, "rolled", false); err != nil {
			log.Printf("[Worker %d]  Failed to update status to rolled for %s: %v", workerID, originalName, err)
		} else {
			log.Printf("[Worker %d]  Successfully processed %s", workerID, originalName)
		}
	}

	return nil
}
