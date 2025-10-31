FROM golang:1.14-alpine as builder

EXPOSE 8080

WORKDIR /tmp
RUN wget https://github.com/yudai/gotty/archive/v1.0.1.tar.gz
RUN tar xzf v1.0.1.tar.gz
WORKDIR /tmp/gotty-1.0.1
COPY ./patch .
RUN apk update && apk add --no-cache git make
RUN git apply 0001-feat-add-patch-cookies-in-env.patch
RUN go mod init && go get

FROM python:3.8-alpine
RUN apk update && apk add --no-cache vim nano curl jq bash
RUN curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/v2.6.7/argocd-linux-amd64
RUN chmod +x /usr/local/bin/argocd
RUN curl -sSL -o /tmp/argo.gz https://github.com/argoproj/argo-workflows/releases/download/v3.1.1/argo-linux-amd64.gz
RUN gunzip /tmp/argo.gz -c > /usr/local/bin/argo && rm /tmp/argo.gz
RUN chmod +x /usr/local/bin/argo

RUN curl -sSL -o /usr/local/bin/sops https://github.com/mozilla/sops/releases/download/v3.6.0/sops-v3.6.0.linux
RUN chmod +x /usr/local/bin/sops

COPY --from=builder /go/bin/gotty /usr/local/bin/
WORKDIR /tmp

ENV PYTHONUNBUFFERED=1
COPY ./requirements.txt .

# Hack to install azure blobstorage without taking too much space
RUN apk add --virtual=build gcc libffi-dev musl-dev openssl-dev make cargo && \
    pip --no-cache-dir install azure-storage-blob && \
    apk del --purge build

RUN pip install -r requirements.txt
RUN rm -rf /var/cache/apk/*
COPY . .
