#!/bin/bash

# This script starts test MapReduce jobs in the queue (pool) specified in the first parameter.
# If a second parameter is specified, it will start that many jobs, otherwise it starts a single job.
# The jobs are based on the SleepJob class, which does nothing but generate fake data and
# sleep a lot.  
# This is to be used during the Fair Scheduler exercise to test/demonstrate how pools work.

# Check that the user supplied two parameters.
if [ $# == 2 ];
  then 
    # User specified both a pool and a number of jobs
    pool=$1
    num=$2
elif [ $# == 1 ];
  then 
    # User specified a pool, use default number of jobs (1)
    pool=$1
    num=1
else
    # Too many or too few arguments
    echo "Wrong number of arguments supplied."
	echo $"Usage: $0 {pool1|pool2|pool3|pool4} [number of jobs]"
	exit 1
fi

echo "Start $num job(s) in queue $pool"

for ((i=1; i<=${num}; i++))
do
  if [ $num > 1 ]; then jobname=${pool}-job${i}; else jobname=${pool}-job; fi
  echo "Starting job" $jobname
  
  # -m = number of map tasks
  # -r = number of reduce tasks
  # -mt = milliseconds to sleep per record (map tasks)
  # -rt = milliseconds to sleep per record (reduce tasks)
  # higher sleep times = longer-running job
  hadoop jar /opt/cloudera/parcels/CDH/lib/hadoop-mapreduce/hadoop-mapreduce-client-jobclient-tests.jar sleep \
    -D mapreduce.job.name=$jobname -D mapreduce.job.queuename=$pool \
    -m 30 -r 30 -mt 20000 -rt 20000 > /dev/null 2>&1 &
done

exit 0
