ThisBuild / scalaVersion := "2.13.18"
ThisBuild / version      := "0.1.0"
ThisBuild / organization := "de.tg.spark"

val sparkVersion = "4.0.3"

lazy val root = (project in file("."))
  .settings(
    name := "spark-gke-deploy-demo",
    idePackagePrefix := Some("de.tg.spark"),

    libraryDependencies ++= Seq(
      // Provided: Spark libs already live inside apache/spark base image.
      // Bundling them again bloats the jar and risks runtime classpath conflicts.
      "org.apache.spark" %% "spark-core" % sparkVersion % Provided,
      "org.apache.spark" %% "spark-sql"  % sparkVersion % Provided
    ),

    // sbt-assembly: merge META-INF junk, otherwise duplicate service files kill the build.
    assembly / assemblyMergeStrategy := {
      case PathList("META-INF", xs @ _*) =>
        xs.map(_.toLowerCase) match {
          case "services" :: _ => MergeStrategy.concat  // keep SPI files
          case _               => MergeStrategy.discard
        }
      case _ => MergeStrategy.first
    },

    // Silence the unused-key warning about idePackagePrefix.
    Global / excludeLintKeys += idePackagePrefix
  )
