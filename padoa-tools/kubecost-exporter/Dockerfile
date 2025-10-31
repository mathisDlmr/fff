FROM mcr.microsoft.com/azure-cli

ENV HOME=/home
RUN chown -R 26:26 /home
RUN apk update && \
    apk upgrade && \
    apk add curl && \
    apk add python3
WORKDIR /home

COPY export_allocation_report.sh .

ENTRYPOINT ["./export_allocation_report.sh"]
