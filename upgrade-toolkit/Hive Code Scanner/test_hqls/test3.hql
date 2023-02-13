SET hive.exec.mode.local.auto=true;
CREATE TABLE mydb.employees (id INT, name STRING, salary FLOAT);
SELECT * FROM employees;