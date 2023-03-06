from pyspark import SparkContext
def main():
   sc = SparkContext(appName='SparkWordCount')
   input_file = sc.textFile('/tmp/sparkinput.txt')
   counts = input_file.flatMap(lambda line: line.split()) \
                     .map(lambda word: (word, 1)) \
                     .reduceByKey(lambda a, b: a + b)
   counts.saveAsTextFile('/tmp/sparkoutput')
   sc.stop()
if __name__ == '__main__':
   main()
