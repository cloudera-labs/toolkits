# Cloudera Developer Training
# This script generates Kafka messages from a set of files.
# Each line in the files is sent the the specified topic as a single
# message.
# 
# Parameters:
#     topic: the name of the Kafka topic to publish messages to
#     broker-list: a comma-separated list of Kafka brokers and ports
#       (e.g. host1:2181,host2:2181)
#     lines-per-second: how fast to generate messages
#     files: one or more files (e.g. datadirectory/*)

arglist="$@"
filelist=${@:2}
linesPerSecond=${arglist:0:1}
sleeptime=`echo 1/$linesPerSecond | bc -l`

arglist=($@)
filelist=${@:2}
linesPerSecond=${arglist[2]}
echo INFO Lines per second: $linesPerSecond
sleeptime=`echo 1/$linesPerSecond | bc -l`
filelist=${@:4}
# echo DEBUG Files: $filelist
topic=${arglist[0]}
echo INFO Topic: $topic
brokerlist=${arglist[1]}
echo INFO Broker List: $brokerlist

# Loop through the list of files, read each line of the
# file, and send each line to stdout

sendlines() {
  # loop through provided list of files
  for f in $filelist; do
    >&2 echo INFO Reading file: $f

    # loop through each line from stdin
    # (stdin is redirected from file at end of loop: < $f)
    while read line; do

      # display info messages to stderr
      >&2 echo INFO Sending line --------------- ;
      >&2 echo $line

      # write current line to stdout
      echo $line
      
      # sleep for 1/lines-per-second seconds
      sleep $sleeptime

    done < $f
  done
}

# call sendlines to read through the file and send each line,
# and pipe output to kafka-console-producer to generate a kafka message
# for each line
sendlines | kafka-console-producer --broker-list $brokerlist --topic $topic
