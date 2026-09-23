package de.tg.spark

import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.expressions.Window
import org.apache.spark.sql.functions._

object
TopOrdersPerCustomerJob {
  def main(args: Array[String]): Unit = {
    /*
    The main goal here is to find the three most recent orders for each customer.
    */
    val bucketName = "spark-on-k8s-data"

    val spark = SparkSession
      .builder()
      .appName("top-orders-per-customer")
      .getOrCreate()


    val ordersDf = spark.read.parquet(s"gs://$bucketName/raw/orders.parquet")

    println("----- ORDERS SCHEMA -----")
    ordersDf.printSchema()

    println("----- ORDERS -----")
    ordersDf.show(5, truncate = false)

    val completedOrdersDf = ordersDf
      .filter(col("status") === "completed")
      .withColumn("order_date", to_date(col("order_ts")))

    println("----- COMPLETED ORDERS -----")
    completedOrdersDf.show(5, truncate = false)

    val customerOrderWindow = Window
      .partitionBy("customer_id")
      .orderBy(col("order_ts").desc)

    val topOrdersPerCustomerDf = completedOrdersDf
      .withColumn("order_rank", row_number().over(customerOrderWindow))
      .filter(col("order_rank") <= 5)
      .orderBy("customer_id", "order_rank")

    println("----- TOP 5 MOST RECENT ORDERS PER CUSTOMER -----")
    topOrdersPerCustomerDf.show(15, truncate = false)

    val outputPath = s"gs://$bucketName/processed/top5_orders_per_customer"
    topOrdersPerCustomerDf.write.mode("overwrite").parquet(outputPath)

    println(s"----- WROTE TOP-5 ORDERS PER CUSTOMER TO $outputPath -----")
  }
}
