FROM alpine:3.17


RUN apk add --no-cache \
  bash \
  bind-tools \
  curl \
  git \
  htop \
  iperf3 \
  iproute2 \
  iputils \
  jq \
  mtr \
  net-tools \
  netcat-openbsd \
  nmap \
  openssh-client \
  openssl \
  postgresql-client \
  procps \
  tcpdump \
  wget \
  ;

ARG KUBECTL_VERSION=1.26.4
RUN set -eux; \
  curl -fsSL \
    -o /usr/local/bin/kubectl \
    https://storage.googleapis.com/kubernetes-release/release/v$KUBECTL_VERSION/bin/linux/amd64/kubectl \
  ; \
  chmod +x /usr/local/bin/kubectl

RUN set -eux; \
  curl -fsSL \
    -o /usr/local/bin/argocd \
    https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 \
  ; \
  chmod +x /usr/local/bin/argocd

RUN set -eux; \
  curl -fsSL \
    -o /usr/local/bin/argo.gz \
    https://github.com/argoproj/argo-workflows/releases/latest/download/argo-linux-amd64.gz \
  ; \
  gunzip /usr/local/bin/argo.gz; \
  chmod +x /usr/local/bin/argo

CMD /bin/bash
