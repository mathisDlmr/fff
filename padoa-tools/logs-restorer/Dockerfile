FROM python:alpine
COPY logsRestorer.py .
COPY requirements.txt .

RUN python -m pip install -r requirements.txt
CMD ["python", "logsRestorer.py"]
