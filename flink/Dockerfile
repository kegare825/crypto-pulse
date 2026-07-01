FROM apache/flink:1.20.0-scala_2.12-java11

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl wget \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/flink/plugins/s3-fs-hadoop \
    && wget -q -P /opt/flink/lib/ \
        https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-kafka/3.4.0-1.20/flink-sql-connector-kafka-3.4.0-1.20.jar \
    && wget -q -P /opt/flink/lib/ \
        https://repo1.maven.org/maven2/org/apache/flink/flink-connector-jdbc/3.3.0-1.20/flink-connector-jdbc-3.3.0-1.20.jar \
    && wget -q -P /opt/flink/lib/ \
        https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.4/postgresql-42.7.4.jar \
    && wget -q -P /opt/flink/lib/ \
        https://repo1.maven.org/maven2/org/apache/flink/flink-metrics-prometheus/1.20.0/flink-metrics-prometheus-1.20.0.jar \
    && wget -q -P /opt/flink/lib/ \
        https://repo1.maven.org/maven2/org/apache/flink/flink-sql-parquet/1.20.0/flink-sql-parquet-1.20.0.jar \
    && wget -q -P /opt/flink/lib/ \
        https://repo1.maven.org/maven2/org/apache/flink/flink-shaded-hadoop-2-uber/2.8.3-10.0/flink-shaded-hadoop-2-uber-2.8.3-10.0.jar \
    && wget -q -O /opt/flink/plugins/s3-fs-hadoop/flink-s3-fs-hadoop-1.20.0.jar \
        https://repo1.maven.org/maven2/org/apache/flink/flink-s3-fs-hadoop/1.20.0/flink-s3-fs-hadoop-1.20.0.jar \
    && chown -R flink:flink /opt/flink/plugins /opt/flink/lib

COPY sql/ /opt/flink/sql/
COPY submit-job.sh /opt/flink/submit-job.sh
COPY watchdog.sh /opt/flink/watchdog.sh
RUN chmod +x /opt/flink/submit-job.sh /opt/flink/watchdog.sh

USER flink
