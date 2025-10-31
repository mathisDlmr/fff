package storage

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"io"
	"net/http"
	"net/url"
)

type StorageClient struct {
	AccountName string
	Container   string
	SASToken    string
}

func NewStorageClient(accountName, container, sasToken string) *StorageClient {
	return &StorageClient{
		AccountName: accountName,
		Container:   container,
		SASToken:    sasToken,
	}
}

func (c *StorageClient) BuildBlobURL(blobName string) string {
	escapedBlob := url.PathEscape(blobName)
	blobURL := fmt.Sprintf("https://%s.blob.core.windows.net/%s/%s", c.AccountName, c.Container, escapedBlob)

	if c.SASToken != "" {
		blobURL += "?" + c.SASToken
	}
	return blobURL
}


func (c *StorageClient) DownloadBlob(ctx context.Context, blobName, key, keyHash, algorithm string) ([]byte, error) {
	blobURL := c.BuildBlobURL(blobName)

	req, err := http.NewRequestWithContext(ctx, "GET", blobURL, nil)
	if err != nil {
		return nil, err
	}

	req.Header.Set("x-ms-encryption-key", key)
	req.Header.Set("x-ms-encryption-key-sha256", keyHash)
	req.Header.Set("x-ms-encryption-algorithm", algorithm)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to download blob %s, status: %s", blobName, resp.Status)
	}

	return io.ReadAll(resp.Body)
}

func (c *StorageClient) UploadBlob(ctx context.Context, blobName string, content []byte, key, keyHash, algorithm string) error {
	blobURL := c.BuildBlobURL(blobName)

	req, err := http.NewRequestWithContext(ctx, "PUT", blobURL, bytes.NewReader(content))
	if err != nil {
		return err
	}

	req.Header.Set("x-ms-encryption-key", key)
	req.Header.Set("x-ms-encryption-key-sha256", keyHash)
	req.Header.Set("x-ms-encryption-algorithm", algorithm)
	req.Header.Set("x-ms-blob-type", "BlockBlob")
	req.Header.Set("Content-Length", fmt.Sprintf("%d", len(content)))

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		return fmt.Errorf("failed to upload blob %s, status: %s", blobName, resp.Status)
	}

	return nil
}

// ComputeSHA256Base64 returns the SHA256 of a key in base64 encoding.
func ComputeSHA256Base64(key string) string {
	hash := sha256.Sum256([]byte(key))
	return base64.StdEncoding.EncodeToString(hash[:])
}
