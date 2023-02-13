SET hive.merge.mapfiles=true;
CREATE TABLE mydb.employees (id INT, name STRING, salary FLOAT);
SELECT * FROM employees;