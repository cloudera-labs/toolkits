echo "Creating Impala tables movie and movieratings"

# Load accounts data into default location for Hive/Impala tables
hdfs dfs -put ~/training_materials/admin/data/moviedata/movie /user/hive/warehouse/movie_hive
hdfs dfs -put ~/training_materials/admin/data/moviedata/movierating /user/hive/warehouse/movierating_hive

# Set up the table to reference the data
impala-shell --impalad=worker-1 -f ~/training_materials/admin/scripts/impala-create-moviedb.sql