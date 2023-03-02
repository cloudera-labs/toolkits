#!/bin/sh

echo "Starting script"
scp -r /ngrams/gz worker-3:/tmp/ngrams_gz > /dev/null 2> /dev/null
ssh worker-3 sudo gunzip /tmp/ngrams_gz/*.gz > /dev/null 2> /dev/null
echo "Done"



