FROM apache/flink:1.20.0-scala_2.12-java11

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl wget \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q -P /opt/flink/lib/ \
        https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-kafka/3.4.0-1.20/flink-sql-connector-kafka-3.4.0-1.20.jar \
    && wget -q -P /opt/flink/lib/ \
        https://repo1.maven.org/maven2/org/apache/flink/flink-connector-jdbc/3.3.0-1.20/flink-connector-jdbc-3.3.0-1.20.jar \
    && wget -q -P /opt/flink/lib/ \
        https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.4/postgresql-42.7.4.jar \
    && wget -q -P /opt/flink/lib/ \
        https://repo1.maven.org/maven2/org/apache/flink/flink-metrics-prometheus/1.20.0/flink-metrics-prometheus-1.20.0.jar

COPY sql/ /opt/flink/sql/
COPY submit-job.sh /opt/flink/submit-job.sh
RUN chmod +x /opt/flink/submit-job.sh

USER flink
