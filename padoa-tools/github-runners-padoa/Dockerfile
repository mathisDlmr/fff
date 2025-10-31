FROM summerwind/actions-runner:latest

USER root

RUN apt-get update -y \
  && apt-get install openssh-client -y \
  && rm -rf /var/lib/apt/lists/*


USER runner
