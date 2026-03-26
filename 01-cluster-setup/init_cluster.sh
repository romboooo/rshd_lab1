rm -rf $HOME/wzo28
mkdir -p $HOME/wzo28
chmod 700 $HOME/wzo28

export PGDATA=$HOME/wzo28
export LC_ALL=ru_RU.CP1251

initdb