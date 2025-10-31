FROM ubuntu:20.04

RUN set -ex; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
  ; \
  rm -rf /var/lib/apt/lists/*

# cf. https://github.com/Azure/azure-cli/issues/30635#issuecomment-2581362583
RUN set -ex; \
  curl https://azcopyvnext-awgzd8g7aagqhzhe.b02.azurefd.net/releases/release-10.24.0-20240326/azcopy_linux_amd64_10.24.0.tar.gz -o /tmp/azcopy.tar.gz; \
  tar -xf /tmp/azcopy.tar.gz -C /tmp; \
  mv /tmp/azcopy_linux_amd64_*/azcopy /usr/local/bin/azcopy; \
  chmod +x /usr/local/bin/azcopy; \
  rm -rf /tmp/azcopy*

COPY log_cleaner.sh /

ENV HOME=/home
RUN chown -R 26:26 /home
WORKDIR /home

ENTRYPOINT ["/log_cleaner.sh"]
