FROM golang:1.22.2 AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN go build -o rotate-main ./cmd/rotate-main.go

FROM alpine:latest

RUN apk add --no-cache ca-certificates
WORKDIR /app
COPY --from=builder /app/rotate-main .

ENTRYPOINT ["/app/rotate-main"]
