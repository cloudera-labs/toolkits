--Cast timestamp warning

SELECT CAST(1597217764557 AS TIMESTAMP); 

--Casting of 0 to null warning
SELECT CAST ('0000-00-00' as date) , 
CAST ( '000-00-00 00:00:00' AS TIMESTAMP) ;