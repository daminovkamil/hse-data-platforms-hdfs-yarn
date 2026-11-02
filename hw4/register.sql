CREATE DATABASE IF NOT EXISTS hse_hw;

DROP TABLE IF EXISTS hse_hw.events_daily_spark;

CREATE EXTERNAL TABLE hse_hw.events_daily_spark (
  event_type STRING,
  event_count BIGINT,
  total_amount DOUBLE
)
PARTITIONED BY (event_date STRING)
STORED AS PARQUET
LOCATION '/data/hse/events_daily_spark';

MSCK REPAIR TABLE hse_hw.events_daily_spark;
