#!/bin/bash

#This script is designed to be used during the Fair Scheduler exercise.
# It kills all jobs running in a particular pool.
#Check that the user supplied two parameters.
if [ $# != 1 ]
  then
    echo "Wrong number of arguments supplied."
	echo "Usage: $0 {pool1|pool2|pool3|pool4}"
	exit 1
fi

#create array to hold found appIds
declare -a runningJobsInPool 
runningJobsInPool=($(sudo yarn application --list | grep $1 | awk '{print $1}'))
#iterate through appIds and kill the jobs
for i in "${runningJobsInPool[@]}"
do
    sudo yarn application -kill $i
done 

exit 0