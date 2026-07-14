"""Integration tests against a real Kafka broker via Testcontainers.

The unit tests in test_coingecko.py / test_binance.py only exercise pure
normalization functions with nothing mocked out. These tests instead run
the real producer config (contracts/kafka_producer.py) against a live
broker to prove the serialize -> publish -> consume -> validate round trip
actually works end-to-end, not just its individual pieces in isolation.

Requires a Docker daemon reachable from the test runner (works out of the
box on GitHub-hosted `ubuntu-latest` runners and on any dev machine with
Docker installed). See requirements-test-integration.txt.
"""

from __future__ import annotations

import json
import sys
import time
import uuid
from pathlib import Path

import pytest

pytest.importorskip("confluent_kafka")
pytest.importorskip("testcontainers")

from confluent_kafka import Consumer, Producer
from confluent_kafka.admin import AdminClient, NewTopic
from testcontainers.kafka import KafkaContainer

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "contracts"))
sys.path.insert(0, str(ROOT / "ingest"))
sys.path.insert(0, str(ROOT / "binance-ingest"))

from coingecko_normalize import normalize_events  # noqa: E402
from kafka_producer import build_producer_config  # noqa: E402
from trade_normalize import normalize_trade  # noqa: E402
from validate_event import is_valid_crypto_price_event  # noqa: E402

# Requires Docker; excluded from the default `pytest tests/ -v` run (see
# pytest.ini) and run in its own CI job — `kafka-integration` in ci.yml.
pytestmark = pytest.mark.integration


@pytest.fixture(scope="module")
def kafka_bootstrap_servers():
    container = KafkaContainer()
    container.start(timeout=120)
    try:
        yield container.get_bootstrap_server()
    finally:
        container.stop()


def _create_topic(bootstrap_servers: str, topic: str) -> None:
    admin = AdminClient({"bootstrap.servers": bootstrap_servers})
    futures = admin.create_topics([NewTopic(topic, num_partitions=1, replication_factor=1)])
    for future in futures.values():
        future.result(timeout=30)


def _consume_one(bootstrap_servers: str, topic: str, timeout_s: float = 20.0):
    consumer = Consumer(
        {
            "bootstrap.servers": bootstrap_servers,
            "group.id": f"test-{uuid.uuid4()}",
            "auto.offset.reset": "earliest",
            "enable.auto.commit": False,
        }
    )
    consumer.subscribe([topic])
    deadline = time.monotonic() + timeout_s
    try:
        while time.monotonic() < deadline:
            msg = consumer.poll(1.0)
            if msg is None:
                continue
            if msg.error():
                continue
            return msg
    finally:
        consumer.close()
    return None


def test_coingecko_event_round_trip_through_real_kafka(kafka_bootstrap_servers) -> None:
    """The real producer config publishes a normalized event that survives
    a live broker round trip and still passes the shared contract."""
    topic = f"test.coingecko.{uuid.uuid4().hex[:8]}"
    _create_topic(kafka_bootstrap_servers, topic)

    events = normalize_events(
        {"bitcoin": {"usd": 61000.5, "usd_market_cap": 1.2e12, "usd_24h_change": 1.1}}
    )
    assert len(events) == 1

    config = build_producer_config()
    config["bootstrap.servers"] = kafka_bootstrap_servers
    producer = Producer(config)
    producer.produce(topic, key=b"bitcoin", value=json.dumps(events[0]).encode("utf-8"))
    producer.flush(timeout=10)

    message = _consume_one(kafka_bootstrap_servers, topic)
    assert message is not None, "expected event was not delivered within timeout"

    received = json.loads(message.value().decode("utf-8"))
    assert received["coin_id"] == "bitcoin"
    assert received["source"] == "coingecko"
    assert is_valid_crypto_price_event(received)


def test_binance_trade_round_trip_through_real_kafka(kafka_bootstrap_servers) -> None:
    topic = f"test.binance.{uuid.uuid4().hex[:8]}"
    _create_topic(kafka_bootstrap_servers, topic)

    trade_event = normalize_trade(
        {"e": "trade", "s": "ETHUSDT", "p": "1650.25", "T": 1_700_000_000_000}
    )
    assert trade_event is not None

    config = build_producer_config()
    config["bootstrap.servers"] = kafka_bootstrap_servers
    producer = Producer(config)
    producer.produce(topic, key=b"ethereum", value=json.dumps(trade_event).encode("utf-8"))
    producer.flush(timeout=10)

    message = _consume_one(kafka_bootstrap_servers, topic)
    assert message is not None, "expected trade event was not delivered within timeout"

    received = json.loads(message.value().decode("utf-8"))
    assert received["coin_id"] == "ethereum"
    assert received["source"] == "binance"
    assert is_valid_crypto_price_event(received)


def test_malformed_message_fails_contract_validation(kafka_bootstrap_servers) -> None:
    """Documents, at the Kafka round-trip layer, exactly the condition that
    triggers the Flink SQL dead-letter path (ADR 007): a payload that is
    not valid JSON must not be silently coerced into something valid."""
    topic = f"test.malformed.{uuid.uuid4().hex[:8]}"
    _create_topic(kafka_bootstrap_servers, topic)

    config = build_producer_config()
    config["bootstrap.servers"] = kafka_bootstrap_servers
    producer = Producer(config)
    producer.produce(topic, value=b"{not valid json")
    producer.flush(timeout=10)

    message = _consume_one(kafka_bootstrap_servers, topic)
    assert message is not None

    raw_value = message.value().decode("utf-8")
    assert raw_value == "{not valid json"
    with pytest.raises(json.JSONDecodeError):
        json.loads(raw_value)
