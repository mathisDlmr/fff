FROM cgr.dev/chainguard/go as builder

RUN mkdir -p /wrk
COPY . /wrk
WORKDIR /wrk

ENV CGO_ENABLED=0
ENV GOOS=linux
#ENV GOARCH=amd64

RUN go build -ldflags "-w -s"

FROM scratch as runner

COPY --from=builder /wrk/tollerator /tollerator

ENTRYPOINT ["/tollerator"]
