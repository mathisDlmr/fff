FROM rockylinux:9.3


RUN rpm --import https://packages.microsoft.com/keys/microsoft.asc
RUN dnf install -y https://packages.microsoft.com/config/rhel/9.0/packages-microsoft-prod.rpm

RUN dnf install -y rpmdevtools rpmlint azure-cli azcopy podman jq createrepo tree
RUN dnf install -y 'dnf-command(builddep)'
