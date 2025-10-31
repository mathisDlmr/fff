package config

import (
	"fmt"
	"os"
)

type Config struct {
	PostgresURL          string
	StorageAccountName   string
	ContainerName        string
	OldEncryptionKey     string
	OldEncryptionKeyHash string
	NewEncryptionKey     string
	NewEncryptionKeyHash string
	EncryptionAlgorithm  string
	SASToken string
}

func Load() (*Config, error) {
	get := func(key string) (string, error) {
		val := os.Getenv(key)
		if val == "" {
			return "", fmt.Errorf("missing env var: %s", key)
		}
		return val, nil
	}

	return &Config{
		PostgresURL:          must(get("POSTGRES_URL")),
		StorageAccountName:   must(get("AZURE_STORAGE_ACCOUNT")),
		ContainerName:        must(get("AZURE_CONTAINER")),
		OldEncryptionKey:     must(get("OLD_CSKE_KEY")),
		OldEncryptionKeyHash: must(get("OLD_CSKE_HASH")),
		NewEncryptionKey:     must(get("NEW_CSKE_KEY")),
		NewEncryptionKeyHash: must(get("NEW_CSKE_HASH")),
		EncryptionAlgorithm:  must(get("ENCRYPTION_ALGORITHM")), // "AES256"
		SASToken: must(get("AZURE_SAS_TOKEN")),

	}, nil
}

func must(val string, err error) string {
	if err != nil {
		panic(err)
	}
	return val
}
