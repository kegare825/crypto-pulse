FROM python:3.12-slim

WORKDIR /app

COPY dlq-monitor/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY dlq-monitor/consumer.py dlq-monitor/dlq_normalize.py dlq-monitor/metrics.py ./

CMD ["python", "-u", "consumer.py"]
