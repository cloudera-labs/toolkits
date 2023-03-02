# Test script:
# $DEVSH/scripts/streamtest-kafka.sh weblogs worker-1:9092 20 $DEVDATA/weblogs/*
# Run application:
# spark2-submit solution-python/StreamingLogsKafka.py weblogs worker-1:9092

import sys
from pyspark import SparkContext
from pyspark.streaming import StreamingContext
from pyspark.streaming.kafka import KafkaUtils

def printRDDcount(rdd): 
    print "Number of requests: "+str(rdd.count())

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print >> sys.stderr, "Usage: StreamingLogsKafka.py <topic> <brokerlist>"
        sys.exit(-1)
    
    topic = sys.argv[1]
    brokerlist = sys.argv[2]
     
    sc = SparkContext()   
    sc.setLogLevel("ERROR")

    # Configure the Streaming Context with a 1 second batch duration
    ssc = StreamingContext(sc,1)

    # Create a DStream of log data from Kafka topic 
    kafkaStream = KafkaUtils.\
       createDirectStream(ssc, [topic], {"metadata.broker.list": brokerlist})

    # The weblog data is in the form (key, value), map to just the value
    logStream = kafkaStream.map(lambda (key,line): line)

    # To test, print the first few lines of each batch of messages to confirm receipt
    logStream.pprint()
        
    # Print out the count of each batch RDD in the stream
    logStream.foreachRDD(lambda t,r: printRDDcount(r))

    # Save the logs
    #logStream.saveAsTextFiles("/loudacre/streamlog/kafkalogs")
    logStream.saveAsTextFiles("/user/training/loudacre/streamlog/kafkalogs")


    ssc.start()
    ssc.awaitTermination()
