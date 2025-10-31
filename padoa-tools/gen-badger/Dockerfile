FROM registry.access.redhat.com/ubi9-minimal:latest as builder

RUN mkdir -p /wrk
COPY . /wrk
WORKDIR /wrk

RUN microdnf -y install go

ENV CGO_ENABLED=0
ENV GOOS=linux
#ENV GOARCH=amd64

RUN go build -ldflags "-w -s"

FROM registry.access.redhat.com/ubi9-minimal:latest as run

RUN microdnf clean all \
    && microdnf upgrade -y --refresh \
         --best \
         --nodocs \
         --noplugins \
         --setopt=install_weak_deps=0 \
    && microdnf clean all
RUN microdnf -y install perl perl-devel
RUN rpm --excludedocs -ivh https://dl.fedoraproject.org/pub/epel/9/Everything/x86_64/Packages/p/perl-UNIVERSAL-isa-1.20171012-13.el9.noarch.rpm
RUN rpm --excludedocs -ivh https://dl.fedoraproject.org/pub/epel/9/Everything/x86_64/Packages/p/perl-Text-CSV_XS-1.46-1.el9.x86_64.rpm
RUN rpm --excludedocs -ivh https://download.postgresql.org/pub/repos/yum/common/redhat/rhel-9-x86_64/pgbadger-12.4-1PGDG.rhel9.noarch.rpm
RUN microdnf clean all

COPY --from=builder /wrk/genBadger /genBadger
COPY ./index.html /index.html
COPY ./public /public

ENTRYPOINT ["/genBadger"]
