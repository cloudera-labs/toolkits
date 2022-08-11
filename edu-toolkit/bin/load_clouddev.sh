#!/bin/bash



ls /var/data/clouddev

rm -r /tmp/clouddev
mkdir /tmp/clouddev

tar -xvzf /var/data/clouddev/consent_data.tar.gz -C /tmp/clouddev/
tar -xvzf /var/data/clouddev/eu_country.tar.gz -C /tmp/clouddev/
tar -xvzf /var/data/clouddev/us_customer.tar.gz -C /tmp/clouddev/
tar -xvzf /var/data/clouddev/ww_customer.tar.gz -C /tmp/clouddev/

echo BadPass@1 | su - dana_dev -c "hdfs dfs -rm -skipTrash /warehouse/tablespace/data/clouddev/*"

echo BadPass@1 | su - dana_dev -c "hdfs dfs -put /tmp/cloudsale/* /warehouse/tablespace/data/clouddev/"
echo BadPass@1 | su - dana_dev -c "hdfs dfs -ls -R /warehouse/tablespace/"
