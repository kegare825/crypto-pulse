FROM python:3.12-slim

WORKDIR /app

COPY binance-ingest/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY contracts/validate_event.py contracts/crypto_price_event.schema.json contracts/kafka_producer.py ./
COPY binance-ingest/binance_producer.py binance-ingest/metrics.py binance-ingest/trade_normalize.py ./

CMD ["python", "-u", "binance_producer.py"]
