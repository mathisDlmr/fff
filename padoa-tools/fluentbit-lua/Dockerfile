FROM ubuntu:focal AS lua-libs

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y libpcre2-dev luarocks

RUN luarocks install lua-cjson 

FROM padoa.azurecr.io/mirror/docker-io/fluent/fluent-bit:3.2.8

COPY --from=lua-libs /usr/local/lib/lua/ /usr/local/lib/lua/

ENTRYPOINT [ "/fluent-bit/bin/fluent-bit" ]
CMD [ "-c", "/fluent-bit/etc/fluent-bit.conf" ]
