FROM golang:1.21-alpine3.19

RUN apk add --update --no-cache \
    bash \
    coreutils \
    curl \
    git \
    jq \
    helm

RUN go install github.com/dadav/helm-schema/cmd/helm-schema@0.11.1
