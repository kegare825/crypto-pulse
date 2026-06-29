FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY validate.py .
COPY run-quality.sh /run-quality.sh
RUN chmod +x /run-quality.sh

CMD ["/run-quality.sh"]
