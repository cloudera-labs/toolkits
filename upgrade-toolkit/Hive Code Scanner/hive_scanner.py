# Copyright 2023 Cloudera, Inc
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

import re
import os
import sys
from data.Recommendations import *
from parsing.HiveSimpleParsing import *


input_hql_dir = 'test_hqls/'
result_output_dir = 'output/'
hive3_cnvsn_fn=result_output_dir+'hive3_conversion_recommendations.csv'

hql_files = []

if __name__ == '__main__':
    #Create class object instances
    rcmdd = Recommendations()
    sp = HiveSimpleParsing()

    # Recursively search the directory for HQL files
    for root, dirs, files in os.walk(input_hql_dir):
        hql_files.extend([os.path.join(root, file) for file in files if file.endswith('.hql') or file.endswith('.properties')])

    # Open the CSV file to write the results
    with open(hive3_cnvsn_fn, mode='w') as csv_file:
        fieldnames = ['file_name', 'line_number', 'problematic_search', 'recommendation']
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        writer.writeheader()

        # Iterate through the HQL files
        for hql_file in hql_files:
            sp.find_table_operations(hql_file, hql_file, writer)

            print("started scan of " + hql_file)
            with open(hql_file, 'r') as f:
                lines = f.readlines()
                for line_number, line in enumerate(lines):
                    #loop all checks
                    if line.startswith("--") != True: # only continue if first characters are not a comment
                        for rc in rcmdd._recommendations_search_arr:
                            if rc[2] == "me":
                                sp.match_experssion(rc, line, line_number + 1, writer, hql_file)
                            else:
                                sp.search_experssion(rc, line, line_number + 1, writer, hql_file)
