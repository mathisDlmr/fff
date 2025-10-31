FROM alpine:3.19

RUN apk add --update --no-cache \
    bash \
    coreutils \
    curl \
    git \
    envsubst \
    jq

# Cf. this official blog post from hashicorp https://www.hashicorp.com/blog/installing-hashicorp-tools-in-alpine-linux-containers
ARG TF_VERSION=1.8.1

RUN apk add --update --virtual .deps --no-cache gnupg && \
    cd /tmp && \
    wget https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip && \
    wget https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_SHA256SUMS && \
    wget https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_SHA256SUMS.sig && \
    wget -qO- https://www.hashicorp.com/.well-known/pgp-key.txt | gpg --import && \
    gpg --verify terraform_${TF_VERSION}_SHA256SUMS.sig terraform_${TF_VERSION}_SHA256SUMS && \
    grep terraform_${TF_VERSION}_linux_amd64.zip terraform_${TF_VERSION}_SHA256SUMS | sha256sum -c && \
    unzip /tmp/terraform_${TF_VERSION}_linux_amd64.zip -d /tmp && \
    mv /tmp/terraform /usr/local/bin/terraform && \
    rm -f /tmp/terraform_${TF_VERSION}_linux_amd64.zip terraform_${TF_VERSION}_SHA256SUMS ${TF_VERSION}/terraform_${TF_VERSION}_SHA256SUMS.sig && \
    apk del .deps

# TFLint
RUN curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
