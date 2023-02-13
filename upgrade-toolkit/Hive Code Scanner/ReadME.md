# Hive Code Scanner

Utilize this code scanner to scan hql files and property files to assess changes that need to be made after upgrade to CDP which utilizes Hive 3
The first file will contain the recommendations for converting your HQL files to be compatible with Hive 3. The second file will contain the table operations such as create, alter and drop with the line number, database and table names that need to be modified with backticks.

## Limitations

This is a Professional Services built artifact and Cloudera cannot verify that every potential change will be detected by this code scanner. Cloudera does not support enhancements to this tool or support this as an official Cloudera artifact. Please engage your account team for any issues you encounter with this product.

If your HQL uses variables, this scanner will only detect variables that are defined within the HQL, not any arguments passed externally

Variables must be declared in the following manner to be properly scanned:

```sh
SET test_var = 'dummy';
SELECT * FROM my_table WHERE column = '${hiveconf:test_var}';
```

If you would like to also scan your properties file the file must have the extension .properties i.e. hive.properties

## Requirements:
* python3 must be installed
* Provide the path to hql files
* Install the required packages

### Modify the below line to provide path to hql files and output directory

The default parameters assume a relative path to the code however this can be modified to a fully qualified path for both the input and output directory

```shell
input_hql_dir = 'test_hqls/'
result_output_dir = 'output/'
```

## Import the following packages

```sh
import os
import csv
import re 
```

## Directions to Execute
```shell
python3 hive_scanner.py
```
