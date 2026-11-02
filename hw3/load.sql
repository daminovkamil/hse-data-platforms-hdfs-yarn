CREATE DATABASE IF NOT EXISTS hse_hw;

CREATE EXTERNAL TABLE IF NOT EXISTS hse_hw.events_raw (
  user_id STRING,
  event_type STRING,
  amount STRING,
  event_date STRING
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/data/hse/events_raw';

CREATE TABLE IF NOT EXISTS hse_hw.events (
  user_id INT,
  event_type STRING,
  amount DOUBLE
)
PARTITIONED BY (event_date STRING)
STORED AS PARQUET;

SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;

INSERT OVERWRITE TABLE hse_hw.events PARTITION (event_date)
SELECT CAST(user_id AS INT), event_type, CAST(amount AS DOUBLE), event_date
FROM hse_hw.events_raw
WHERE user_id RLIKE '^[0-9]+$'
  AND amount RLIKE '^[0-9]+(\\.[0-9]+)?$'
  AND event_date RLIKE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$';
