#!/usr/bin/env python3
import os
from pyspark.sql import SparkSession
from pyspark.sql.functions import avg, col


def main():
    # Decide master: prefer env or default to spark standalone master URL
    spark_master = os.environ.get("SPARK_MASTER", "spark://spark-master:7077")

    # Paths inside containers
    # In containers, '/data' maps to the repo root, so actual CSVs live under '/data/data'
    data_dir = "/data/data"
    shared_dir = "/shared"
    sample_csv = os.path.join(data_dir, "sample.csv")
    edges_csv = os.path.join(data_dir, "edges.csv")
    out_dir = os.path.join(shared_dir, "verify_cluster_out")

    print(f"SPARK_MASTER: {spark_master}")
    print(f"Reading sample: {sample_csv}")
    print(f"Reading edges:  {edges_csv}")
    print(f"Writing out:    {out_dir}")

    spark = (
        SparkSession.builder
        .appName("verify-cluster")
        .master(spark_master)
        .config("spark.ui.enabled", "false")
        .getOrCreate()
    )

    sc = spark.sparkContext
    print("Spark master:", sc.master)
    print("Spark version:", spark.version)

    # 1) Tiny RDD sanity check (executor work)
    n = sc.parallelize(range(1000), numSlices=sc.defaultParallelism).map(lambda x: x * 2).sum()
    print("RDD sum result (expected 999*1000):", n)

    # 2) DataFrame read from shared RO mount
    df = spark.read.option("header", True).option("inferSchema", True).csv(sample_csv)
    print("Rows in sample:", df.count())
    agg = df.groupBy("department").agg(avg(col("salary")).alias("avg_salary")).orderBy(col("avg_salary").desc())
    agg.show(truncate=False)

    # 3) Optional: edges quick count
    if os.path.exists(edges_csv):
        edges_rdd = sc.textFile(edges_csv)
        header = edges_rdd.first()
        if "src" in header.lower():
            edges_rdd = edges_rdd.filter(lambda l: l != header)
        print("Edges count (no header):", edges_rdd.count())

    # 4) Write output to shared RW mount
    (agg.coalesce(1)
        .write.mode("overwrite").option("header", True)
        .csv(out_dir))
    print("Wrote results to:", out_dir)

    spark.stop()


if __name__ == "__main__":
    main()
