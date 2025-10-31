FROM hashicorp/terraform:1.11.4 as terraform

FROM mcr.microsoft.com/azure-cli

ENV KUBECTL_VERSION=v1.32.6

RUN tdnf install -y \
gettext \
git \
openssh \
nmap-ncat \
awk \
&& tdnf clean all

RUN curl -LO https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl \
    && chmod +x ./kubectl \
    && mv ./kubectl /usr/local/bin/kubectl

COPY --from=terraform /bin/terraform /bin/terraform
COPY run.sh /run.sh
COPY backend.tf /backend.tf

ENTRYPOINT ["/bin/bash"]

CMD ["run.sh"]
