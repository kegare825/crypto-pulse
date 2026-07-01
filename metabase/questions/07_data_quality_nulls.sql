-- Null and sanity checks on gold marts
SELECT mart, total_rows, null_prices, non_positive_prices
FROM gold.mart_gold_sanity;
