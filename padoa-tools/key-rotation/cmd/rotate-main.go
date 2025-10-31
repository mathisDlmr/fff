package main

import (
	"context"
	"log"
	"sync"

	"github.com/joho/godotenv"
	"key-rotation/config"
	"key-rotation/internal/db"
	"key-rotation/internal/worker"
)

const (
	workerCount = 10
	batchSize   = 30
)

func main() {
	ctx := context.Background()

	_ = godotenv.Load()

	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("failed to load config: %v", err)
	}

	dbClient, err := db.Connect(cfg.PostgresURL)
	if err != nil {
		log.Fatalf("failed to connect to DB: %v", err)
	}
	defer dbClient.Close()

	log.Println("Starting key rotation workflow...")

	var wg sync.WaitGroup
	workerCh := make(chan int, workerCount)

	for i := 0; i < workerCount; i++ {
		wg.Add(1)
		workerCh <- i
		go func(workerID int) {
			defer wg.Done()
			for {
				batch, err := db.FetchPendingBatch(ctx, dbClient, batchSize)
				if err != nil {
					log.Printf("[Worker %d] error fetching batch: %v", workerID, err)
					return
				}
				if len(batch) == 0 {
					log.Printf("[Worker %d] no more pending files.", workerID)
					return
				}

				log.Printf("[Worker %d] picked up %d files:", workerID, len(batch))
				for _, f := range batch {
					log.Printf("[Worker %d]  - %s", workerID, f.S3Name)
				}

				err = worker.ProcessBatch(ctx, dbClient, cfg, batch, workerID)
				if err != nil {
					log.Printf("[Worker %d] error processing batch: %v", workerID, err)
				}
			}
		}(i)
	}

	wg.Wait()
	log.Println("All workers completed.")
}
