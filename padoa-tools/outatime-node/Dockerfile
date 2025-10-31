ARG NODE_VERSION

FROM node:"${NODE_VERSION}-alpine"

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
# Fix the struct stat64 issue by replacing it with struct stat
RUN sed -i 's/struct stat64/struct stat/g' /libfaketime-$LIBFAKETIME_VERSION/src/libfaketime.c
RUN make install --directory "/libfaketime-$LIBFAKETIME_VERSION/src"

COPY ./libfaketime.sh /usr/local/bin/use-faketime

# FAKETIME will be set command by command as changing the time can break some of them

ENTRYPOINT [ "/bin/bash" ]
