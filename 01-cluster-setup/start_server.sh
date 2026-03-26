export PGDATA=$HOME/wzo28
pg_ctl -D $PGDATA -l $PGDATA/server_start.log start