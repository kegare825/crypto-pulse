FROM python:3.12-slim

WORKDIR /app

COPY ingest/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY contracts/validate_event.py contracts/crypto_price_event.schema.json contracts/kafka_producer.py ./
COPY ingest/producer.py ingest/consumer.py ingest/metrics.py ingest/coingecko_normalize.py ./

CMD ["python", "-u", "producer.py"]
