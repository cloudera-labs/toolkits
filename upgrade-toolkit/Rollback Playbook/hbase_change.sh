#!/bin/bash
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

## Disable automatic Balancer and Normalizer in HBase. Also disable Split and Merge procedures, before stopping the CDP 7 Cluster.
echo 'balance_switch false' | hbase shell -n
status=$?
if [$status -ne 0]; then
  echo "The command may have failed."
fi
echo 'normalizer_switch false' | hbase shell -n
status=$?
if [$status -ne 0]; then
  echo "The command may have failed."
fi
echo 'splitormerge_switch 'SPLIT', false' | hbase-shell -n
status=$?
if [$status -ne 0]; then
  echo "The command may have failed."
fi
echo 'splitormerge_switch 'MERGE', false' | hbase-shell -n
status=$?
if [$status -ne 0]; then
  echo "The command may have failed."
fi



