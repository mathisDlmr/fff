# Use bitnami legacy after Bitnami Catalog deprecation
# When upgrading make sure that the new tag exists in the bitnami legacy catalog
FROM bitnamilegacy/kubectl:1.32 as kubectl

FROM alpine:3

RUN apk add --no-cache bash

COPY --from=kubectl /opt/bitnami/kubectl/bin/kubectl /usr/local/bin/

# Create directory for the script
RUN mkdir -p /scripts

# Copy the benchmark script
COPY ./pg_benchmark.sh /scripts/pg_benchmark.sh
RUN chmod +x /scripts/pg_benchmark.sh

# Copy the entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"] 
