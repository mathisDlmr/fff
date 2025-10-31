FROM alpine
RUN apk add --update --no-cache py3-pip
COPY requirements.txt .
RUN pip install --break-system-packages -r requirements.txt
COPY indices-restorer.py .
