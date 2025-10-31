FROM postgres:11-alpine

ARG LIBFAKETIME_VERSION=0.9.9

# General dependencies
RUN apk add --update --no-cache --no-progress \
    make        \
    gcc         \
    musl-dev    \
    bash        \
    coreutils

# Get the lib
RUN wget "https://github.com/wolfcw/libfaketime/archive/refs/tags/v$LIBFAKETIME_VERSION.tar.gz"
RUN tar -xvzf "v$LIBFAKETIME_VERSION.tar.gz"
RUN make install --directory "/libfaketime-$LIBFAKETIME_VERSION/src"

COPY ./libfaketime.sh libfaketime.sh
COPY ./00-create-roles.sh /docker-entrypoint-initdb.d/

ENTRYPOINT [ ]
CMD [ "./libfaketime.sh", "docker-entrypoint.sh postgres" ]
