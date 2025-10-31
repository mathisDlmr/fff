package model

type File struct {
	FileID  string
	S3Name  string
}

type FileEncryption struct {
	FileID  string
	Status  string
	Retries int
}
