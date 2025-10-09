import os
from pyspark.sql import SparkSession
from pyspark.sql.functions import avg, col


def main():
    project_root = os.path.abspath(os.path.dirname(os.path.dirname(__file__)))
    data_path = os.path.join(project_root, 'data', 'sample.csv')
    out_dir = os.path.join(project_root, 'output')
    os.makedirs(out_dir, exist_ok=True)

    spark = SparkSession.builder.master("local[*]").appName("sample_pyspark_project").getOrCreate()

    df = spark.read.option("header", True).option("inferSchema", True).csv(data_path)
    print("--- Schéma du DataFrame ---")
    df.printSchema()

    print("--- Aperçu (10 premières lignes) ---")
    df.show(10, truncate=False)

    agg = df.groupBy("department").agg(avg(col("salary")).alias("avg_salary"))
    print("--- Salaire moyen par département ---")
    agg.orderBy(col("avg_salary").desc()).show(truncate=False)

    # Écriture du résultat
    out_path = os.path.join(out_dir, 'avg_by_dept')
    agg.coalesce(1).write.mode('overwrite').option('header', True).csv(out_path)
    print(f"Résultats écrits dans : {out_path}")

    spark.stop()


if __name__ == '__main__':
    main()
