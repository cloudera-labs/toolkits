#!/bin/bash

DOMAINS=("google.com" "yahoo.com" "msn.com")
HOSTS=("host1" "ppp2" "dsl3")
PATHS=("/docs/foo.html" "/images/bar.jpg" "/style/baz.css")
AGENTS=("Mozilla" "Safari" "Firefox" "IE")

function logrotate()
{
  if [ -e $LOG.5 ]
  then
    rm $LOG.5
  fi
  if [ -e $LOG.4 ]
  then
    mv $LOG.4 $LOG.5
  fi
  if [ -e $LOG.3 ]
  then
    mv $LOG.3 $LOG.4
  fi
  if [ -e $LOG.2 ]
  then
    mv $LOG.2 $LOG.3
  fi
  if [ -e $LOG.1 ]
  then
    mv $LOG.1 $LOG.2
  fi
  if [ -e $LOG.0 ]
  then
    mv $LOG.0 $LOG.1
  fi
  mv $LOG $LOG.0
  touch $LOG
}

function generate_record()
{
  timestamp=`date "+[%d/%b/%Y:%T %z]"`
  num_domains=${#DOMAINS[*]}
  num_hosts=${#HOSTS[*]}
  num_paths=${#PATHS[*]}
  num_agents=${#AGENTS[*]}
  domain=${DOMAINS[$((RANDOM%num_domains))]}
  host=${HOSTS[$((RANDOM%num_hosts))]}
  path=${PATHS[$((RANDOM%num_paths))]}
  agent=${AGENTS[$((RANDOM%num_agents))]}
  bytes=$((RANDOM%10240))
  
  echo "$host.$domain - - $timestamp 200 \"GET $path HTTP/1.0\" $bytes \"-\" \"$agent\"" >> $LOG
}

if [ ! -n "$1" ]
then
  echo "Usage: `basename $0` logfile"
  exit
fi
LOG=$1

counter=0
while true; do
  generate_record
  let counter=counter+1
  if [ $counter == 10 ]
  then
    logrotate
    counter=0
  fi
  sleep 1
done
