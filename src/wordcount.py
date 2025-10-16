#!/usr/bin/env python3
"""
Simple Spark wordcount script suitable for spark-submit.
Usage:
  spark-submit src/wordcount.py <input_path> <output_dir>

The script writes CSV files into <output_dir> (coalesced to 1 file for convenience).
"""
import sys
import os
import re
from pyspark.sql import SparkSession


def main(argv):
    if len(argv) < 3:
        print("Usage: wordcount.py <input_path> <output_dir>")
        sys.exit(2)

    input_path = argv[1]
    output_dir = argv[2]

    spark = SparkSession.builder.appName('wordcount').getOrCreate()
    sc = spark.sparkContext

    if not os.path.exists(os.path.dirname(output_dir)) and not output_dir.startswith('/shared'):
        # try to create local parent if running locally
        try:
            os.makedirs(os.path.dirname(output_dir), exist_ok=True)
        except Exception:
            pass

    pattern = re.compile(r"[a-z']+")

    def tokenize(line):
        return pattern.findall(line.lower())

    text = sc.textFile(input_path)
    words = text.flatMap(tokenize).filter(lambda w: len(w) > 0)
    counts = words.map(lambda w: (w, 1)).reduceByKey(lambda a, b: a + b)

    # Convert to DataFrame for a CSV write with header
    counts_df = spark.createDataFrame(counts, schema=['word', 'count'])
    counts_df = counts_df.orderBy(counts_df['count'].desc())

    # Coalesce to one file for easy consumption (may be slow for huge datasets)
    counts_df.coalesce(1).write.mode('overwrite').option('header', True).csv(output_dir)

    print('Wordcount written to', output_dir)
    spark.stop()


if __name__ == '__main__':
    main(sys.argv)
