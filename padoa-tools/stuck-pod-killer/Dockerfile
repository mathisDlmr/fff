# Multi-stage build for minimal image size
FROM golang:1.25-alpine AS builder

WORKDIR /build

# Install dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY main.go ./

# Build the binary
RUN CGO_ENABLED=0 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -o stuck-pod-killer \
    main.go

# Final minimal image
FROM gcr.io/distroless/static:nonroot

WORKDIR /app

# Copy the binary from builder
COPY --from=builder /build/stuck-pod-killer /app/

# Use non-root user
USER 65534:65534

ENTRYPOINT ["/app/stuck-pod-killer"]
