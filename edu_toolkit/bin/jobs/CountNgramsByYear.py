# Count NGrams By Year
import sys
from pyspark.sql import SparkSession

if __name__ == "__main__":

  if len(sys.argv) < 2:
    print >> sys.stderr, "Usage: CountByYear.py <output-directory>"
    sys.exit()

  spark = SparkSession.builder.getOrCreate()

  ngramsDF = spark.read.table("ngrams_zipped")
  countByYearDF = ngramsDF.groupBy("year").count().sort("year")
  countByYearDF.write.csv(sys.argv[1])

  spark.stop()
