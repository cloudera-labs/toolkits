-- This test case tests whether the scanner correctly detects the use of the keywords 'application', 'time', 'numeric', and 'sync' in the query

SELECT COUNT(*) FROM mydb.mytable WHERE application = 'myapp' AND time BETWEEN '2022-01-01' AND '2022-12-31';

CREATE TABLE mydb.mytable2 AS
SELECT numeric_col, sync_col
FROM mydb.mytable
WHERE application = 'myapp' AND time BETWEEN '2022-01-01' AND '2022-12-31';
