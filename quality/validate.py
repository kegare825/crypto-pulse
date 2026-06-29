"""Run Great Expectations validations across raw, silver, and gold zones."""

from __future__ import annotations

import os
import sys
from datetime import datetime, timezone, timedelta

import great_expectations as gx
import pandas as pd
import psycopg2

ALLOWED_COINS = {"bitcoin", "ethereum", "solana"}
ALLOWED_SOURCES = {"coingecko", "binance"}
FRESHNESS_MINUTES = int(os.environ.get("GE_FRESHNESS_MINUTES", "10"))


def pg_connection():
    return psycopg2.connect(
        host=os.environ.get("POSTGRES_HOST", "postgres"),
        port=int(os.environ.get("POSTGRES_PORT", "5432")),
        dbname=os.environ.get("POSTGRES_DB", "cryptopulse"),
        user=os.environ.get("POSTGRES_USER", "pulse"),
        password=os.environ.get("POSTGRES_PASSWORD", "pulse"),
    )


def load_frame(conn, query: str) -> pd.DataFrame:
    return pd.read_sql_query(query, conn)


def run_expectations(
    df: pd.DataFrame,
    suite_name: str,
    *,
    check_freshness: bool = False,
    check_compound_unique: bool = True,
    check_source: bool = False,
) -> bool:
    context = gx.get_context(mode="ephemeral")
    data_source = context.data_sources.add_pandas(name=f"ds_{suite_name}")
    data_asset = data_source.add_dataframe_asset(name=suite_name)
    batch_definition = data_asset.add_batch_definition_whole_dataframe("whole")
    batch = batch_definition.get_batch(batch_parameters={"dataframe": df})
    validator = context.get_validator(batch=batch)

    validator.expect_table_row_count_to_be_between(min_value=1)
    validator.expect_column_values_to_not_be_null("coin_id")
    validator.expect_column_values_to_not_be_null("price_usd")
    validator.expect_column_values_to_be_in_set("coin_id", sorted(ALLOWED_COINS))
    validator.expect_column_min_to_be_between(column="price_usd", min_value=0, strict_min=True)

    if check_compound_unique and "recorded_at" in df.columns:
        if "source" in df.columns:
            validator.expect_compound_columns_to_be_unique(["coin_id", "source", "recorded_at"])
        else:
            validator.expect_compound_columns_to_be_unique(["coin_id", "recorded_at"])

    if check_source and "source" in df.columns:
        validator.expect_column_values_to_be_in_set("source", sorted(ALLOWED_SOURCES))

    if "recorded_at" in df.columns:
        validator.expect_column_values_to_not_be_null("recorded_at")

    result = validator.validate()
    for exp in result.results:
        status = "OK" if exp.success else "FAIL"
        print(f"  [{status}] {exp.expectation_config.type}")

    ok = bool(result.success)
    if check_freshness and "recorded_at" in df.columns and not df.empty:
        ok = check_data_freshness(df) and ok
    return ok


def check_data_freshness(df: pd.DataFrame) -> bool:
    max_ts = pd.to_datetime(df["recorded_at"], utc=True).max()
    age = datetime.now(timezone.utc) - max_ts.to_pydatetime()
    ok = age <= timedelta(minutes=FRESHNESS_MINUTES)
    status = "OK" if ok else "FAIL"
    print(f"  [{status}] freshness: last event {age} ago (limit {FRESHNESS_MINUTES}m)")
    return ok


def validate_raw(conn) -> bool:
    print("=== raw.crypto_prices ===")
    df = load_frame(
        conn,
        """
        SELECT coin_id, source, symbol, price_usd, market_cap, change_24h, recorded_at
        FROM raw.crypto_prices
        WHERE recorded_at >= NOW() - INTERVAL '24 hours'
        """,
    )
    if df.empty:
        print("  [WARN] no rows in last 24 hours")
        return False
    df["price_usd"] = df["price_usd"].astype(float)
    ok = run_expectations(
        df,
        "raw_crypto_prices",
        check_freshness=True,
        check_source=True,
    )
    print(f"raw => {'PASS' if ok else 'FAIL'}\n")
    return ok


def validate_silver(conn) -> bool:
    print("=== silver.crypto_prices_clean ===")
    df = load_frame(
        conn,
        """
        SELECT coin_id, source, symbol, price_usd, market_cap, change_24h, recorded_at
        FROM silver.crypto_prices_clean
        WHERE recorded_at >= NOW() - INTERVAL '24 hours'
        """,
    )
    if df.empty:
        print("  [WARN] silver table empty (run dbt first)")
        return False
    df["price_usd"] = df["price_usd"].astype(float)
    ok = run_expectations(df, "silver_crypto_prices_clean", check_source=True)
    print(f"silver => {'PASS' if ok else 'FAIL'}\n")
    return ok


def validate_gold_comparison(conn) -> bool:
    print("=== gold.mart_source_price_comparison ===")
    df = load_frame(
        conn,
        """
        SELECT coin_id, coingecko_price_usd, binance_price_usd, spread_usd, spread_pct
        FROM gold.mart_source_price_comparison
        """,
    )
    if df.empty:
        print("  [WARN] comparison mart empty (need both sources in dbt run)")
        return False

    ok = len(df) > 0
    for _, row in df.iterrows():
        print(
            f"  [INFO] {row['coin_id']}: coingecko={row['coingecko_price_usd']} "
            f"binance={row['binance_price_usd']} spread={row['spread_usd']}"
        )
    print(f"gold comparison => {'PASS' if ok else 'FAIL'}\n")
    return ok


def validate_gold(conn) -> bool:
    print("=== gold.mart_latest_prices ===")
    df = load_frame(
        conn,
        """
        SELECT coin_id, symbol, price_usd, market_cap, change_24h, last_recorded_at AS recorded_at
        FROM gold.mart_latest_prices
        """,
    )
    if df.empty:
        print("  [WARN] gold mart empty (run dbt first)")
        return False
    df["price_usd"] = df["price_usd"].astype(float)
    ok = run_expectations(
        df,
        "gold_mart_latest_prices",
        check_compound_unique=False,
    )
    if len(df) != len(ALLOWED_COINS):
        print(f"  [FAIL] expected {len(ALLOWED_COINS)} coins, got {len(df)}")
        ok = False
    else:
        print(f"  [OK] one row per tracked coin ({len(df)})")
    print(f"gold => {'PASS' if ok else 'FAIL'}\n")
    return ok


def main() -> int:
    print("Great Expectations — data platform validation\n")
    with pg_connection() as conn:
        results = [
            validate_raw(conn),
            validate_silver(conn),
            validate_gold(conn),
            validate_gold_comparison(conn),
        ]

    if all(results):
        print("All zone validations passed")
        return 0
    print("Some validations failed")
    return 1


if __name__ == "__main__":
    sys.exit(main())
