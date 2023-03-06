#!/bin/bash
#
# Create a new spool directory and move weblog files into it
# 

# Temporary staging area to copy weblog files to
TMPWEBLOGS=/tmp/tmp_weblogs

# Where the weblogs source data exists
SOURCEDIR=/home/training/training_materials/admin/data/weblogs

if [ -z "$1" ]
then
  echo "Usage: `basename $0` spooldirpath"
  exit $E_BADARGS
fi

# Directory must exist
if [ -e "$1" ]
then
  # Directory must be empty (no *.COMPLETED files from prior run)
  if [ "$(ls $1)" ]; then
    echo "$1 exists and is not empty, delete contents? (y/n)"
    read RESPONSE
    if [ "$RESPONSE" = "y" ]; then
      rm -rf $1/*
    else
      echo "$1 is not empty, exiting"
      exit 1
    fi
  fi
else
  echo "$1 does not exist, exiting"
  exit 1
fi

echo "Copying and moving files to $1"

cp -rf $SOURCEDIR $TMPWEBLOGS
mv $TMPWEBLOGS/* $1/
rm -rf $TMPWEBLOGS