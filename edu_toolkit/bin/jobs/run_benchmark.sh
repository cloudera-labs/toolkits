#!/bin/bash

# This script is for training purposes only and is to be used only
# in support of approved training. The author assumes no liability
# for use outside of a training environments. Unless required by
# applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES
# OR CONDITIONS OF ANY KIND, either express or implied.

# Title: run-benchmark.sh
# Author: WKD  
# Date: 1MAR18
# Purpose: This script runs benchmarking tools, such as terasort and DFSIO. 
# The data, sort, and report files are located in hdfs.  
# Log files are located in ~/log.

# DEBUG
#set -x
#set -eu
#set >> /root/setvar.txt

# VARIABLES
NUMARGS=$#
DIR=${HOME}
TERAJAR=/usr/hdp/current/hadoop-mapreduce-client/hadoop-mapreduce-examples.jar
DFSIOJAR=/usr/hdp/current/hadoop-mapreduce-client/hadoop-mapreduce-client-jobclient-tests.jar
BENCHDIR=/data/benchmark
DATETIME=$(date +%Y%m%d%H%M)
LOGFILE="${DIR}/log/run-benchmark.log"

# FUNCTION
function usage() {
        echo "Usage: $(basename $0)" 1>&2
        exit 1
}

function callInclude() {
# Test for script and run functions

        if [ -f ${DIR}/sbin/include.sh ]; then
                source ${DIR}/sbin/include.sh
        else
                echo "ERROR: The file ${DIR}/sbin/include.sh not found."
                echo "This required file provides supporting functions."
		exit 1
        fi
}

function makeHDFSDir}() {

	# Create the HDFS base directory
	sudo -u hdfs hdfs dfs -mkdir -p ${BENCHDIR}
}

function intro() {
	echo -e "\nBench Runner may be a long running script."
	echo "If required terminate this script with Ctrl-C "
	echo
}

function setSizeRows() {
# List and select the sizes for the benchmark

	echo "Set the SIZE and ROWS of the tera sort file."
	echo
	echo "A) Size = 1G, Rows = 10000000"
	echo "B) Size = 10G, Rows = 100000000"
	echo "C) Size = 100G, Rows = 1000000000"
	echo "D) Size = 500G, Rows = 5000000000"
	echo "E) Size = 1T, Rows = 10000000000"
	echo
	read -p "Select a letter to set SIZE and ROWS: " SIZEROWS
	
	case "${SIZEROWS}" in
		A | a)
			SIZE=1G
			ROWS=10000000
			;;
		B | b)
			SIZE=10G
			ROWS=100000000
			;;
		C | c)
			SIZE=100G
			ROWS=1000000000
			;;
		D | d)
			SIZE=500G
			ROWS=5000000000
			;;
		E | e)
			SIZE=1T
			ROWS=10000000000
			;;
		*)
			echo "ERROR: An incorrect letter was selected for SIZE and ROWS."
	esac 

	# Set hidden local file to contain last size
	echo ${SIZE} > ${DIR}/.terasize
}

function setTera() {
# Set the parameters for the benchmark

	SIZE=$(cat ${DIR}/.terasize)

	# Set the HDFS input directory
	INPUTDIR=${BENCHDIR}/teragen-${SIZE}-input

	# Set the HDFS output directory
	OUTPUTDIR=${BENCHDIR}/teragen-${SIZE}-output

	# Set the HDFS report directory
	REPORTDIR=${BENCHDIR}/teragen-${SIZE}-report	

	# Kill any running MapReduce jobs
	mapred job -list | grep job_ | awk ' { system("mapred job -kill " $1) } '
}

function runTeraGen() {
# Run TeraGen

	# Delete the HDFS input directory from previous run jobs
	sudo -u hdfs hdfs dfs -rm -r -f -skipTrash ${INPUTDIR}

	# Run teragen
	time yarn jar ${TERAJAR} teragen \
		-Dmapreduce.map.log.level=INFO \
		-Dmapreduce.reduce.log.level=INFO \
		-Dyarn.app.mapreduce.am.log.level=INFO \
		-Dio.file.buffer.size=131072 \
		-Dmapreduce.map.cpu.vcores=1 \
		-Dmapreduce.map.java.opts=-Xmx1536m \
		-Dmapreduce.map.maxattempts=1 \
		-Dmapreduce.map.memory.mb=2048 \
		-Dmapreduce.map.output.compress=true \
		-Dmapreduce.map.output.compress.codec=org.apache.hadoop.io.compress.Lz4Codec \
		-Dmapreduce.reduce.cpu.vcores=1 \
		-Dmapreduce.reduce.java.opts=-Xmx1536m \
		-Dmapreduce.reduce.maxattempts=1 \
		-Dmapreduce.reduce.memory.mb=2048 \
		-Dmapreduce.task.io.sort.factor=100 \
		-Dmapreduce.task.io.sort.mb=384 \
		-Dyarn.app.mapreduce.am.command.opts=-Xmx768m \
		-Dyarn.app.mapreduce.am.resource.mb=1024 \
		-Dmapred.map.tasks=92 \
		${ROWS} ${OUTDIR} >> ${LOGFILE} 2>&1
		
		# These are optional log levels for debugging
		#-Dmapreduce.map.log.level=TRACE \
		#-Dmapreduce.reduce.log.level=TRACE \
		#-Dyarn.app.mapreqduce.am.log.level=TRACE \
}

function runTeraSort() {
# Run TeraSort

	# Delete the output directory
	sudo -u hdfs hdfs dfs -rm -r -f -skipTrash ${OUTPUTDIR} 

	# Run terasort
	time yarn jar $MR_EXAMPLES_JAR terasort \
		-Dmapreduce.map.log.level=INFO \
		-Dmapreduce.reduce.log.level=INFO \
		-Dyarn.app.mapreduce.am.log.level=INFO \
		-Dio.file.buffer.size=131072 \
		-Dmapreduce.map.cpu.vcores=1 \
		-Dmapreduce.map.java.opts=-Xmx1536m \
		-Dmapreduce.map.maxattempts=1 \
		-Dmapreduce.map.memory.mb=2048 \
		-Dmapreduce.map.output.compress=true \
		-Dmapreduce.map.output.compress.codec=org.apache.hadoop.io.compress.Lz4Codec \
		-Dmapreduce.reduce.cpu.vcores=1 \
		-Dmapreduce.reduce.java.opts=-Xmx1536m \
		-Dmapreduce.reduce.maxattempts=1 \
		-Dmapreduce.reduce.memory.mb=2048 \
		-Dmapreduce.task.io.sort.factor=300 \
		-Dmapreduce.task.io.sort.mb=384 \
		-Dyarn.app.mapreduce.am.command.opts=-Xmx768m \
		-Dyarn.app.mapreduce.am.resource.mb=1024 \
		-Dmapred.reduce.tasks=92 \
		-Dmapreduce.terasort.output.replication=1 \
		${INPUTDIR} ${OUTPUT} >> ${LOGFILE} 2>&1
}

function runvalidate() {
# Run Validate

	# Delete the output directory
	sudo -u hdfs hdfs dfs -rm -r -f -skipTrash ${REPORTDIR}

	# Run teravalidate
	time yarn jar ${TERAJAR} teravalidate \
		-Ddfs.blocksize=256M \
		-Dio.file.buffer.size=131072 \
		-Dmapreduce.map.memory.mb=2048 \
		-Dmapreduce.map.java.opts=-Xmx1536m \
		-Dmapreduce.reduce.memory.mb=2048 \
		-Dmapreduce.reduce.java.opts=-Xmx1536m \
		-Dyarn.app.mapreduce.am.resource.mb=1024 \
		-Dyarn.app.mapreduce.am.command-opts=-Xmx768m \
		-Dmapreduce.task.io.sort.mb=1 \
		-Dmapred.map.tasks=185 \
		-Dmapred.reduce.tasks=185 \
		${OUTPUTDIR} ${REPORTDIR} >> ${LOGFILE} 2>&1
}

function teraloop() {
# This function loops the use of TeraSort

	MEM=2048

	# Set range of mappers
	for i in {16,32,64}; do
        	# Set range of reducers
        	for j in {4,8,16}; do

			# For each run generate a terasort file
			time yarn jar ${TERAJAR} teragen \
				-D mapreduce.job.maps=$i \
				-D mapreduce.map.memory.mb=${MEM} 100000 \
				${BENCHDIR}/loop/input-$i-$j 1>${LOGFILE}-$i-$j

			# For each run sort the terasort file
			time yarn jar ${TERAJAR} terasort \
				-D mapreduce.job.maps=$i \
			 	-D mapreduce.job.reduces=$j \
				-D mapreduce.map.memory.mb=${MEM} \
				-D mapreduce.reduce.memory.mb=${MEM} \
				${BENCHDIR}/loop/input-$i-$j ${BENCHDIR}/loop/output-$i-$j 1>>${LOGFILE}-$i-$j

			# Run the validate to create a record
			time yarn jar ${TERAJAR} teravalidate \
				-Dmapreduce.map.memory.mb=2048 \
				-Dmapreduce.reduce.memory.mb=2048 \
				${BENCHDIR}/loop/input-$i-$j ${BENCHDIR}/loop/report-$i-$j >> ${LOGFILE} 2>&1

			# Clean up
			sudo -u hdfs hdfs dfs -rm -r ${BENCHDIR}/loop/input-$i-$j
			sudo -u hdfs hdfs dfs -rm -r ${BENCHDIR}/loop/output-$i-$j
    		done
	done
}

function setDFSIO() {
# Setup the DFSIO sort benchmark

	# Set number of files and file size.
	read -p "Set number of files: " FILES
	read -p "Set file size: " FILESIZE	

	DFSIO_WRITE="${LOGDIR}/dfsio_write_${DATETIME}.txt"
	DFSIO_READ="${LOGDIR}/dfsio_read_${DATETIME}.txt"
}

function runDFSIOClean() {
# Run the DFSIO benchmark

	# run DFSIO clean
	echo "Running DFSIO Clean job"
	yarn jar ${DFSIOJAR} -clean
}

function runDFSIOWrite() {
# Run the DFSIOWrite benchmark

	# run DFSIO write
	echo "Running DFSIO Write job"
	yarn jar ${DFSIOJAR} \
		-write -nrfiles ${FILES} \
		-filesize ${FILESIZE} \
		-resfile ${DFSIO_WRITE}
}

function runDFSIORead() {
# Run the DFSIORead benchmark

	# run DFSIO read
	echo "Running DFSIO Read job"
	yarn jar ${DFSIOJAR} \
		-read -nrfiles ${FILES} \
		-filesize ${FILESIZE} \
		-resfile ${DFSIO_READ}
}

function cleanlog() {
# Remove the previous benchmark logs

	echo "Deleting DFSIO logs"
	rm -r ${LOGDIR}/*
}

function runOption() {
# Select benchmark tool

	read -p "Set the benchmark [teragen|terasort|validate|loop|dfsio|cleanLogs]: " OPTION

	case ${OPTION} in 
		teragen)
			setSizeRows
			setTera
			runTeraGen
			;;
		terasort)
			setTera
			runTeraSort
			;;
		validate)
			setTera
			runTeraValidate
			;;
		dfsio)
			setDFSIO
			runDFSIOClean
			runDFSIOWrite
			runDFSIORead
			;;
		cleanLogs)
			cleanLogs
			;;
		*)
			usage
			;;
	esac
}

# MAIN
# Source functions
callInclude

# Run checks
checkSudo

# Run option
trap "interrupt 1" 1 2 3 15
intro
runOption
