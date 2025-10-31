FROM summerwind/actions-runner:latest

USER root

RUN apt-get update -y \
  && apt-get install -y jq curl gzip bash openssh-client \
  && rm -rf /var/lib/apt/lists/*

ARG argo_version=v2.12.9
RUN curl -LO "https://github.com/argoproj/argo-workflows/releases/download/${argo_version}/argo-linux-amd64.gz" && \
  gunzip argo-linux-amd64.gz && \
  chmod +x ./argo-linux-amd64 && \
  mv ./argo-linux-amd64 /usr/local/bin/argo

ARG argocd_version=v1.7.8
RUN curl -LO "https://github.com/argoproj/argo-cd/releases/download/${argocd_version}/argocd-linux-amd64" && \
  chmod +x ./argocd-linux-amd64 && \
  mv ./argocd-linux-amd64 /usr/local/bin/argocd

USER runner
