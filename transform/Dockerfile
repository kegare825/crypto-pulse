FROM python:3.12-slim

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash \
    && rm -rf /var/lib/apt/lists/*

COPY transform/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

COPY dbt/ /app/dbt/
COPY orchestration/ /app/orchestration/
COPY quality/validate.py /app/validate.py
COPY transform/entrypoint.sh /app/entrypoint.sh
COPY transform/run-transform.sh /app/run-transform.sh
RUN chmod +x /app/entrypoint.sh /app/run-transform.sh

ENV DBT_PROFILES_DIR=/app/dbt
ENV DAGSTER_HOME=/tmp/dagster
ENV PYTHONPATH=/app
WORKDIR /app/dbt

EXPOSE 3002

CMD ["/app/entrypoint.sh"]
