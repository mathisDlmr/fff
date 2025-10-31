FROM python:alpine

RUN pip install --upgrade pip && \
    pip install --no-cache-dir requests==2.26.0

COPY . /scripts

WORKDIR /scripts
