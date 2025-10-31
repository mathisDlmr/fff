# Use bitnami legacy after Bitnami Catalog deprecation
# When upgrading make sure that the new tag exists in the bitnami legacy catalog
FROM bitnamilegacy/kubectl:1.32 as kubectl

FROM alpine:3.18

RUN apk --no-cache add curl
RUN apk add --no-cache bash

COPY --from=kubectl /opt/bitnami/kubectl/bin/kubectl /usr/local/bin/
