"""Read and print messages from the CoinGecko Kafka topic."""

from __future__ import annotations

import json
import os
import sys

from confluent_kafka import Consumer, KafkaException


def main() -> None:
    bootstrap_servers = os.environ.get("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
    topic = os.environ.get("KAFKA_TOPIC", "coingecko.prices.raw")
    group_id = os.environ.get("KAFKA_CONSUMER_GROUP", "crypto-pulse-debug")

    consumer = Consumer(
        {
            "bootstrap.servers": bootstrap_servers,
            "group.id": group_id,
            "auto.offset.reset": "earliest",
            "enable.auto.commit": True,
        }
    )
    consumer.subscribe([topic])

    print(f"Listening on topic '{topic}' via {bootstrap_servers} (Ctrl+C to stop)")
    try:
        while True:
            message = consumer.poll(1.0)
            if message is None:
                continue
            if message.error():
                raise KafkaException(message.error())

            payload = json.loads(message.value().decode("utf-8"))
            print(
                f"[partition={message.partition()} offset={message.offset()}] "
                f"{payload['coin_id']} price_usd={payload['price_usd']} "
                f"event_time={payload['event_time']}"
            )
    except KeyboardInterrupt:
        print("\nStopped.")
    finally:
        consumer.close()


if __name__ == "__main__":
    main()
