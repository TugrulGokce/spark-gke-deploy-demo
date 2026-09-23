FROM apache/spark:4.0.3

USER root

# gcs-connector: Spark 4.x / Hadoop 3.4 compatible — enables gs:// URI support
# TODO(medium): 644 = rw-r--r--, root olarak indirilen jar'i USER 185 okuyabilsin diye world-readable yapiyoruz
ADD --chmod=644 https://storage.googleapis.com/hadoop-lib/gcs/gcs-connector-hadoop3-2.2.21.jar \
    /opt/spark/jars/gcs-connector.jar

# DataFlint: live 4040 UI + history server visualization on GKE
RUN curl -fSL \
    "https://repo1.maven.org/maven2/io/dataflint/dataflint-spark4_2.13/0.9.9/dataflint-spark4_2.13-0.9.9.jar" \
    -o /opt/spark/jars/dataflint-spark4_2.13-0.9.9.jar && \
    chmod 644 /opt/spark/jars/dataflint-spark4_2.13-0.9.9.jar

COPY target/scala-2.13/spark-gke-deploy-demo-assembly-0.1.0.jar /opt/spark/jars/app.jar

# TODO(medium): 185, apache/spark base image'inin kendi tanimladigi non-root "spark" kullanicisinin UID'si
# TODO (Spark'in resmi K8s Dockerfile'inda ARG spark_uid=185). Root ile jar eklendikten sonra guvenlik icin bu kullaniciya donuyoruz.
# TODO source: https://github.com/apache/spark/blob/master/resource-managers/kubernetes/docker/src/main/dockerfiles/spark/Dockerfile
USER 185
