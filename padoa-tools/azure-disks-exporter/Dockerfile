FROM python:3.9-slim

WORKDIR /app

COPY exporter.py /app/

RUN pip install azure-identity azure-mgmt-compute requests

CMD ["python", "exporter.py"]
