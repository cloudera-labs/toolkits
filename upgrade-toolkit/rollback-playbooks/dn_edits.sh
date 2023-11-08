#!/usr/bin/env bash
# Copyright 2022 Cloudera, Inc
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

PID=$!
#############################################################
#### Data node configuration files -- Begin
#############################################################
# 1. ssl-server.xml (TLS only)
# a. change property 'ssl.server.keystore.password' value
# b. change property 'ssl.server.keystore.keypassword' value
# c. remove property 'hadoop.security.credential.provider.path'
sed '/<name>ssl.server.keystore.password<\/name>/!b;n;c<value>changeme</value>' ssl-server.xml | \
sed '/<name>ssl.server.keystore.keypassword<\/name>/!b;n;c<value>changeme</value>' | \
sed -e '/<name>hadoop.security.credential.provider.path<\/name>/,+1 d' > ssl-server-new.xml
mv ssl-server.xml ssl-server.xml.orig
mv ssl-server-new.xml ssl-server.xml


# 2. hdfs-site.xml
# remove property 'dfs.datanode.max.locked.memory'
sed -e '/<name>dfs.datanode.max.locked.memory<\/name>/,+1 d' /etc/hadoop/conf.rollback.datanode/hdfs-site.xml > /etc/hadoop/conf.rollback.datanode/hdfs-site-new.xml
mv /etc/hadoop/conf.rollback.datanode/hdfs-site.xml /etc/hadoop/conf.rollback.datanode/hdfs-site.xml.orig
mv /etc/hadoop/conf.rollback.datanode/hdfs-site-new.xml /etc/hadoop/conf.rollback.datanode/hdfs-site.xml

#############################################################
#### Data node configuration files -- Finish
#############################################################
cd /etc/hadoop/conf.rollback.datanode
sudo -u hdfs hdfs --config /etc/hadoop/conf.rollback.datanode datanode -rollback
sleep 300
# Kill it
kill $PID
