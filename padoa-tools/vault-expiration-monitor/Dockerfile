FROM python:3.11-alpine

RUN apk add --no-cache curl jq

RUN pip install hvac requests python-dateutil

COPY vault-expiration-monitor.py /app/

WORKDIR /app
CMD ["python", "vault-expiration-monitor.py"]
