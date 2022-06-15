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

mkdir -p /etc/hadoop/conf.rollback.datanode/
cd /var/run/cloudera-scm-agent/process/ && cd `ls -t1 | grep -e "-DATANODE\$" | head -1`
cp -rp * /etc/hadoop/conf.rollback.datanode/
rm -rf /etc/hadoop/conf.rollback.datanode/log4j.properties
cp -rp /etc/hadoop/conf.cloudera.hdfs/log4j.properties /etc/hadoop/conf.rollback.datanode/
cp -rp /etc/hadoop/conf.cloudera.yarn/log4j.properties /etc/hadoop/conf.rollback.datanode/
