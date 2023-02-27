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

class HiveSimpleParsing:

    def find_table_operations(self, file_path, hql_file, writer):
        with open(file_path, 'r') as f:
            text = f.read()
        for match in re.finditer(r'(CREATE|ALTER|DROP|CREATE\s+EXTERNAL|CREATE\s+TEMPORARY)\s+(TABLE|TABLE\s+IF\s+NOT\s+EXISTS)\s+(\w+\.)(\w+)', text, re.DOTALL | re.IGNORECASE):
            db_name = match.group(3).replace(".","")
            table_name = match.group(4)
            operations = match.group(2)
            line_number = text.count('\n', 0, match.start()) + 1
            writer.writerow({'file_name': hql_file, 'line_number': line_number, 'problematic_search':'table operations' ,'recommendation': 'Enclose the database name and the table name in backticks AS `{db}`.`{tbl}`'.format(db=db_name,tbl=table_name)})

    def match_experssion(self, rc, line, line_number, writer, fname):
        x = re.match(rc[3], line, re.IGNORECASE)
        if x:
            writer.writerow({'file_name': fname, 'line_number': line_number, 'problematic_search': rc[0], 'recommendation': rc[1]})
            
    def search_experssion(self, rc, line, line_number, writer, fname):
        x = re.search(rc[3], line, re.IGNORECASE)
        if x:
            writer.writerow({'file_name': fname, 'line_number': line_number, 'problematic_search': rc[0], 'recommendation': rc[1]})

