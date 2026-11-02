"""Aggregate HDFS events by date and type, then write Hive-readable Parquet partitions."""

import argparse

from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import StringType, StructField, StructType


def main(input_path: str, output_path: str) -> None:
    spark = SparkSession.builder.appName("hse-hw4-events-daily").getOrCreate()
    try:
        if spark.sparkContext.master != "yarn":
            raise RuntimeError(f"Expected a YARN session, got {spark.sparkContext.master}")
        print(f"YARN application: {spark.sparkContext.applicationId}")

        schema = StructType(
            [
                StructField("user_id", StringType()),
                StructField("event_type", StringType()),
                StructField("amount", StringType()),
                StructField("event_date", StringType()),
            ]
        )
        raw = spark.read.schema(schema).option("mode", "FAILFAST").csv(input_path)
        events = raw.select(
            F.col("user_id").cast("int").alias("user_id"),
            F.trim("event_type").alias("event_type"),
            F.col("amount").cast("double").alias("amount"),
            F.date_format(F.to_date("event_date", "yyyy-MM-dd"), "yyyy-MM-dd").alias(
                "event_date"
            ),
        )
        invalid = events.filter(
            F.col("user_id").isNull()
            | F.col("event_type").isNull()
            | (F.col("event_type") == "")
            | F.col("amount").isNull()
            | F.isnan("amount")
            | F.col("event_date").isNull()
        ).count()
        if invalid:
            raise ValueError(f"Input contains {invalid} invalid event rows: {input_path}")

        daily = events.groupBy("event_date", "event_type").agg(
            F.count("*").alias("event_count"),
            F.sum("amount").alias("total_amount"),
        )
        daily.write.mode("overwrite").partitionBy("event_date").parquet(output_path)
        written = spark.read.parquet(output_path)
        print(f"Wrote {written.count()} groups to {output_path}")
    finally:
        spark.stop()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, help="HDFS URI of the input CSV")
    parser.add_argument("--output", required=True, help="HDFS URI of the output directory")
    args = parser.parse_args()
    main(args.input, args.output)
