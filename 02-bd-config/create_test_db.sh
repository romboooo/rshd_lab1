
psql -h 127.0.0.1 -p 9867 -U postgres2 -d postgres -c "DROP DATABASE IF EXISTS bench_test2;"

psql -h 127.0.0.1 -p 9867 -U postgres2 -d postgres -c "
  CREATE DATABASE bench_test2 
  WITH TEMPLATE = template0 
  ENCODING = 'SQL_ASCII' 
  LC_COLLATE = 'ru_RU.CP1251' 
  LC_CTYPE = 'ru_RU.CP1251';
"

pgbench -h $PGHOST -p $PGPORT -U $PGUSER -i --scale=10 bench_test2
