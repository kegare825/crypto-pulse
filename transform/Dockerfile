FROM python:3.12-slim

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash \
    && rm -rf /var/lib/apt/lists/*

COPY transform/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

COPY dbt/ /app/dbt/
COPY quality/validate.py /app/validate.py
COPY transform/run-transform.sh /app/run-transform.sh
RUN chmod +x /app/run-transform.sh

ENV DBT_PROFILES_DIR=/app/dbt
WORKDIR /app/dbt

CMD ["/app/run-transform.sh"]
