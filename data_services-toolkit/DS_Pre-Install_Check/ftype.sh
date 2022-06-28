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

# remove old files
rm -rf /tmp/ftype.txt /tmp/check_xfs.txt /tmp/ftype.txt /tmp/ftype_compare.txt
df -T | awk '{print $1,$2,$NF}' | grep "^/dev" | awk '{print $1}' > check_xfs.txt
xfs_paths=$(cat check_xfs.txt)
for i in $xfs_paths
do
xfs_info $i | grep "ftype" | awk '{print $6}'
xfs_info $i | grep "ftype" | awk '{print $6}' >> ftype.txt
done

ftype_out=$(cat ftype.txt)
for j in $ftype_out
do
var1="ftype=1"
var2=$j
if [ "$var1" != "$var2" ]; then
    echo $j >> ftype_compare.txt
fi
done
[ -s ftype_compare.txt ] && echo "has wrong ftype" || echo "ftype=1"
