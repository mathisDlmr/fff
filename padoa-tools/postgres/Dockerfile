# https://github.com/postgis/docker-postgis/issues/216#issuecomment-981824739
ARG PG_VERSION=14
ARG LIBFAKETIME_VERSION=0.9.9
ARG TARGETARCH

FROM postgis/postgis:"${PG_VERSION}-3.2" as pg-amd64
FROM ghcr.io/baosystems/postgis:"${PG_VERSION}-3.2" as pg-arm64
FROM pg-${TARGETARCH} as builder

ARG LIBFAKETIME_VERSION

# General dependencies
RUN set -ex; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    clang \
    coreutils \
    gcc \
    libc-dev \
    postgresql-server-dev-14 \
    llvm \
    make \
    wget \
  ; \
  rm -rf /var/lib/apt/lists/*

# Get the lib
RUN wget "https://github.com/wolfcw/libfaketime/archive/refs/tags/v${LIBFAKETIME_VERSION}.tar.gz"
RUN tar -xvzf "v$LIBFAKETIME_VERSION.tar.gz"
RUN make install --directory "/libfaketime-$LIBFAKETIME_VERSION/src"


FROM pg-${TARGETARCH} as pg

# Disable password
ENV POSTGRES_HOST_AUTH_METHOD=trust

ARG LIBFAKETIME_VERSION
ARG TARGETARCH

COPY --from=builder "/libfaketime-$LIBFAKETIME_VERSION/src/libfaketime.so.1" "/tmp/"
COPY --from=builder "/libfaketime-$LIBFAKETIME_VERSION/src/libfaketimeMT.so.1" "/tmp/"
COPY --from=builder "/libfaketime-$LIBFAKETIME_VERSION/src/faketime" "/tmp/"

RUN install -dm0755 "/usr/local/lib/faketime/"
RUN install -m0644 "/tmp/libfaketime.so.1" "/tmp/libfaketimeMT.so.1" "/usr/local/lib/faketime/"
RUN install -Dm0755 "/tmp/faketime" "/usr/local/bin/faketime"

COPY libfaketime.sh libfaketime.sh
COPY 00-create-roles.sh /docker-entrypoint-initdb.d/
COPY 11-create-extensions.sh /docker-entrypoint-initdb.d/
COPY 99-create-ready-file.sh /docker-entrypoint-initdb.d/

RUN apt-get update; \
    apt-get install -y --no-install-recommends \
    postgresql-14-pg-rrule;

COPY make-extensions-trusted.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/make-extensions-trusted.sh && \
    /usr/local/bin/make-extensions-trusted.sh

ENTRYPOINT [ "./libfaketime.sh", "docker-entrypoint.sh" ]
CMD [ "postgres" ]
