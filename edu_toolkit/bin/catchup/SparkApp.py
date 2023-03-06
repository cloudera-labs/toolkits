import sys
from pyspark import SparkContext
from pyspark import SparkConf
sc = SparkContext()
file = sc.textFile("hdfs://elephant:8020/tmp/shakespeare.txt")
counts = file.flatMap(lambda line: line.split(" ")).map(lambda word: (word, 1)).reduceByKey(lambda a, b: a + b).sortByKey() 
counts.saveAsTextFile("hdfs://elephant:8020/tmp/sparkcount")
