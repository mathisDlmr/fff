ARG ES_VERSION=7.17.28

FROM docker.elastic.co/elasticsearch/elasticsearch:${ES_VERSION} AS dist

ARG LIBFAKETIME_VERSION=0.9.9

RUN set -ex; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
  bash \
  make \
  wget \
  gcc \
  coreutils \
  libc6-dev 

RUN wget "https://github.com/wolfcw/libfaketime/archive/refs/tags/v${LIBFAKETIME_VERSION}.tar.gz" && \
  tar -xvzf "v${LIBFAKETIME_VERSION}.tar.gz" && \
  make install --directory "libfaketime-${LIBFAKETIME_VERSION}/src"

RUN install -dm0755 /usr/local/lib/faketime/

COPY ./libfaketime.sh /usr/local/bin/libfaketime.sh
RUN chmod +x /usr/local/bin/libfaketime.sh

USER elasticsearch
ENTRYPOINT ["/bin/tini", "--", "/usr/local/bin/libfaketime.sh", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["eswrapper"]
