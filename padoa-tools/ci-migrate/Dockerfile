FROM alpine:3.11

RUN apk add --update --no-cache \
    bash \
    coreutils \
    curl \
    git \
    jq \
    tzdata \
    util-linux

ARG argo_version=v2.12.9
RUN curl -LO "https://github.com/argoproj/argo-workflows/releases/download/${argo_version}/argo-linux-amd64.gz" && \
    gunzip argo-linux-amd64.gz && \
    chmod +x ./argo-linux-amd64 && \
    mv ./argo-linux-amd64 /usr/local/bin/argo

ARG argocd_version=v1.7.8
RUN curl -LO "https://github.com/argoproj/argo-cd/releases/download/${argocd_version}/argocd-linux-amd64" && \
    chmod +x ./argocd-linux-amd64 && \
    mv ./argocd-linux-amd64 /usr/local/bin/argocd

RUN cp /usr/share/zoneinfo/Europe/Paris /etc/localtime && \
    echo "Europe/Paris" > /etc/timezone && \
    apk del tzdata
