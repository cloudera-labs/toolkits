-- Test case 1
CREATE DATABASE test_db;

CREATE DATABASE IF NOT EXISTS test_db2;

-- Test case 2
USE test_db;

-- Test case 3
CREATE TABLE test_db.table1 (col1 INT, col2 STRING);

-- Test case 4
ALTER TABLE test_db.table1 ADD COLUMNS (col3 FLOAT);

-- Test case 5
DROP TABLE test_db.table1;

-- Test case 6
CREATE TABLE test_db.table2 (col1 INT, col2 STRING)
PARTITIONED BY (col3 FLOAT)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE;


-- Test case 7
CREATE EXTERNAL TABLE test_db.table3_external_case (col1 INT, col2 STRING);

--Test case 8 lowercase
create table test_db.table4_lcase (col1 INT, col2 STRING);

--Test case 9
	create table test_db.table6_tab_beggining_of_line (col1 INT, col2 STRING);
	
-- Test case 10
CREATE external TABLE test_db.table7_external_mixed_case (col1 INT, col2 STRING);

-- Test case 11
CREATE TEMPORARY TABLE test_db.table8_temporary (col1 INT, col2 STRING);

-- Test case 12
CREATE TABLE IF NOT EXISTS test_db.table9_not_exists(col1 INT, col2 STRING);