# Custom Jupyter image aligned with official Apache Spark image (Java 21 + Python 3)
ARG SPARK_IMAGE=spark:4.0.0-java21-python3
FROM ${SPARK_IMAGE}
ARG PYSPARK_VERSION=4.0.0

# Install JupyterLab and Python tooling
USER root
RUN apt-get update && apt-get install -y python3-pip && rm -rf /var/lib/apt/lists/*
RUN pip3 install --no-cache-dir jupyterlab pandas matplotlib pyspark==${PYSPARK_VERSION}

# The driver (jovyan, uid 1000) and the executors (spark, uid 185) both write into
# /shared: make the directories and files Spark creates writable by everyone
RUN mkdir -p /opt/spark/conf && echo "spark.hadoop.fs.permissions.umask-mode 000" >> /opt/spark/conf/spark-defaults.conf

ENV PYSPARK_PYTHON=python3
ENV SPARK_HOME=/opt/spark

# Create jovyan-like user home
RUN useradd -m -s /bin/bash jovyan && mkdir -p /home/jovyan/work && chown -R jovyan:jovyan /home/jovyan
USER jovyan
WORKDIR /home/jovyan/work
