# Use bitnami legacy after Bitnami Catalog deprecation
# When upgrading make sure that the new tag exists in the bitnami legacy catalog
FROM bitnamilegacy/kubectl:1.32 as kubectl

FROM mcr.microsoft.com/azure-cli:2.51.0

COPY --from=kubectl /opt/bitnami/kubectl/bin/kubectl /usr/local/bin/

COPY . .
