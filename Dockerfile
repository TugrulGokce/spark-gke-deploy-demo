FROM apache/spark:4.0.3

USER root

# GCS connector (compatible with Spark 4.x / Hadoop 3.4), adds gs:// URI support
# chmod 644 makes the jar readable by the non-root user the image runs as
ADD --chmod=644 https://storage.googleapis.com/hadoop-lib/gcs/gcs-connector-hadoop3-2.2.21.jar \
    /opt/spark/jars/gcs-connector.jar

# DataFlint, Spark UI and History Server visualization
RUN curl -fSL \
    "https://repo1.maven.org/maven2/io/dataflint/dataflint-spark4_2.13/0.9.9/dataflint-spark4_2.13-0.9.9.jar" \
    -o /opt/spark/jars/dataflint-spark4_2.13-0.9.9.jar && \
    chmod 644 /opt/spark/jars/dataflint-spark4_2.13-0.9.9.jar

# Application fat jar built by sbt assembly
COPY target/scala-2.13/spark-gke-deploy-demo-assembly-0.1.0.jar /opt/spark/jars/app.jar

# Switch back to the non-root spark user (UID 185 in the base image) after adding the jars
# https://github.com/apache/spark/blob/master/resource-managers/kubernetes/docker/src/main/dockerfiles/spark/Dockerfile
USER 185
