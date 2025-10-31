ARG PG_VERSION=11.16
ARG LIBFAKETIME_VERSION=0.9.9

FROM postgres:"${PG_VERSION}-alpine" as builder
ARG LIBFAKETIME_VERSION

# General dependencies
RUN apk add --update --no-cache --no-progress \
    make \
    gcc \
    libexecinfo-dev \
    libc-dev \
    clang \
    llvm \
    musl-dev \
    bash \
    coreutils

# Get the lib
RUN wget "https://github.com/wolfcw/libfaketime/archive/refs/tags/v${LIBFAKETIME_VERSION}.tar.gz"
RUN tar -xvzf "v$LIBFAKETIME_VERSION.tar.gz"
RUN make install --directory "/libfaketime-$LIBFAKETIME_VERSION/src"

FROM postgres:"${PG_VERSION}-alpine" as pg
# Disable password
ENV POSTGRES_HOST_AUTH_METHOD=trust

ARG LIBFAKETIME_VERSION

COPY --from=builder "/libfaketime-$LIBFAKETIME_VERSION/src/libfaketime.so.1" "/tmp/"
COPY --from=builder "/libfaketime-$LIBFAKETIME_VERSION/src/libfaketimeMT.so.1" "/tmp/"
COPY --from=builder "/libfaketime-$LIBFAKETIME_VERSION/src/faketime" "/tmp/"

RUN install -dm0755 "/usr/local/lib/faketime/"
RUN install -m0644 "/tmp/libfaketime.so.1" "/tmp/libfaketimeMT.so.1" "/usr/local/lib/faketime/"
RUN install -Dm0755 "/tmp/faketime" "/usr/local/bin/faketime"

COPY ./libfaketime.sh libfaketime.sh
COPY ./00-create-roles.sh /docker-entrypoint-initdb.d/

CMD [ "./libfaketime.sh", "docker-entrypoint.sh postgres" ]
