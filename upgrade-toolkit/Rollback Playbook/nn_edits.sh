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



#############################################################
#### Name node configuration files -- Begin
#############################################################
# 1. ssl-server.xml (TLS only)
# a. change property 'ssl.server.keystore.password' value
# b. change property 'ssl.server.keystore.keypassword' value
# c. remove property 'hadoop.security.credential.provider.path'
sed '/<name>ssl.server.keystore.password<\/name>/!b;n;c<value>changeme</value>' ssl-server.xml > ssl-server-1.xml
sed '/<name>ssl.server.keystore.keypassword<\/name>/!b;n;c<value>changeme</value>' ssl-server-1.xml > ssl-server-2.xml
sed -e '/<name>hadoop.security.credential.provider.path<\/name>/,+1 d' ssl-server-2.xml > ssl-server-3.xml
mv ssl-server.xml ssl-server.xml.orig
mv ssl-server-3.xml ssl-server.xml

sed '/<name>ssl.server.keystore.password<\/name>/!b;n;c<value>changeme</value>' ssl-server.xml | \
sed '/<name>ssl.server.keystore.keypassword<\/name>/!b;n;c<value>changeme</value>' | \
sed -e '/<name>hadoop.security.credential.provider.path<\/name>/,+1 d' > ssl-server-new.xml
mv ssl-server.xml ssl-server.xml.orig
mv ssl-server-new.xml ssl-server.xml

# 2. hdfs-site.xml
# a. Delete property 'cloudera.navigator.client.config'
# b. Delete property 'dfs.namenode.audit.loggers'
# c. change property 'dfs.hosts' value
sed -e '/<name>cloudera.navigator.client.config<\/name>/,+1 d' /etc/hadoop/conf.rollback.namenode/hdfs-site.xml | \
sed -e '/<name>dfs.namenode.audit.loggers<\/name>/,+1 d' | \
sed '/<name>dfs.hosts<\/name>/!b;n;c<value>/etc/hadoop/conf.rollback.namenode/dfs_all_hosts.txt</value>' > /etc/hadoop/conf.rollback.namenode/hdfs-site-new.xml
mv /etc/hadoop/conf.rollback.namenode/hdfs-site.xml /etc/hadoop/conf.rollback.namenode/hdfs-site.xml.orig
mv /etc/hadoop/conf.rollback.namenode/hdfs-site-new.xml /etc/hadoop/conf.rollback.namenode/hdfs-site.xml

# 3. core-site.xml
# change property 'net.topology.script.file.name' value
sed '/<name>net.topology.script.file.name<\/name>/!b;n;c<value>/etc/hadoop/conf.rollback.namenode/topology.py</value>' /etc/hadoop/conf.rollback.namenode/core-site.xml > /etc/hadoop/conf.rollback.namenode/core-site-new.xml
mv /etc/hadoop/conf.rollback.namenode/core-site.xml /etc/hadoop/conf.rollback.namenode/core-site.xml.orig
mv /etc/hadoop/conf.rollback.namenode/core-site-new.xml /etc/hadoop/conf.rollback.namenode/core-site.xml

# 4. topology.py
# change MAP_FILE property
# assume the line we need to change always follows line "def main():"
sed '/def main():/!b;n;c\ \ MAP_FILE = \x27/etc/hadoop/conf.rollback.namenode/topology.py\x27' /etc/hadoop/conf.rollback.namenode/topology.py > /etc/hadoop/conf.rollback.namenode/topology-new.py
mv /etc/hadoop/conf.rollback.namenode/topology.py /etc/hadoop/conf.rollback.namenode/topology.py.orig
mv /etc/hadoop/conf.rollback.namenode/topology-new.py /etc/hadoop/conf.rollback.namenode/topology.py

#############################################################
#### Name node configuration files -- Finish
#############################################################

sudo -u hdfs hdfs --config /etc/hadoop/conf.rollback.namenode namenode -rollback

