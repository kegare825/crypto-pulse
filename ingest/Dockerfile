FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY producer.py consumer.py metrics.py coingecko_normalize.py ./

CMD ["python", "-u", "producer.py"]
