
export PGDATA="$HOME/wzo28"
export PGHOST="127.0.0.1"
export PGPORT="9867"
export PGUSER="postgres2"
export DBNAME="bench_test2"
export CONF_FILE="$PGDATA/postgresql.conf"
export LOG_FILE="$HOME/optimization_full_log.txt"

MAX_ITERATIONS=25
BENCH_DURATION=15
MEMORY_LIMIT_KB=1572864

CUR_SHARED_BUFFERS=512
CUR_WORK_MEM=8
CUR_MAX_CONN=20
CUR_EFFECTIVE_CACHE=1536
CUR_CHECKPOINT=30
CUR_COMMIT_DELAY=0
CUR_TEMP_BUFFERS=16
CUR_FSYNC=on

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

update_param() {
    local param=$1
    local value=$2
    local unit=$3
    sed -i '' "s|^#*[[:space:]]*${param}[[:space:]]*=.*|${param} = ${value}${unit}|" "$CONF_FILE"
}

check_memory() {
    local shared_kb=$(($CUR_SHARED_BUFFERS * 1024))
    local work_total_kb=$(($CUR_MAX_CONN * $CUR_WORK_MEM * 1024))
    local temp_total_kb=$(($CUR_MAX_CONN * $CUR_TEMP_BUFFERS * 1024))
    local total=$((shared_kb + work_total_kb + temp_total_kb))
    [ $total -gt $MEMORY_LIMIT_KB ] && return 1
    return 0
}

measure_score() {
    pg_ctl -D "$PGDATA" -m fast restart > /dev/null 2>&1
    sleep 4
    if ! pg_ctl -D "$PGDATA" status > /dev/null 2>&1; then
        echo "0"
        return
    fi
    local out
    out=$(pgbench -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -c 8 -j 4 -T "$BENCH_DURATION" "$DBNAME" 2>/dev/null)
    local tps
    tps=$(echo "$out" | grep "tps =" | awk '{print $3}')
    [ -z "$tps" ] && tps="0"
    echo "$tps"
}

is_greater() {
    awk -v a="$1" -v b="$2" 'BEGIN { exit (a > b ? 0 : 1) }'
}

apply_config() {
    update_param "shared_buffers" "$CUR_SHARED_BUFFERS" "MB"
    update_param "work_mem" "$CUR_WORK_MEM" "MB"
    update_param "max_connections" "$CUR_MAX_CONN" ""
    update_param "effective_cache_size" "$CUR_EFFECTIVE_CACHE" "MB"
    update_param "checkpoint_timeout" "$CUR_CHECKPOINT" "min"
    update_param "commit_delay" "$CUR_COMMIT_DELAY" ""
    update_param "temp_buffers" "$CUR_TEMP_BUFFERS" "MB"
    update_param "fsync" "$CUR_FSYNC" ""
}

echo "" > "$LOG_FILE"
log "=== Полная оптимизация (8 параметров) ==="
log "Старт: shared_buffers=${CUR_SHARED_BUFFERS}MB, work_mem=${CUR_WORK_MEM}MB, max_connections=${CUR_MAX_CONN}"

apply_config
BASE_SCORE=$(measure_score)
log "Базовый TPS: $BASE_SCORE"

BEST_SCORE=$BASE_SCORE
ITERATION=1

while [ $ITERATION -le $MAX_ITERATIONS ]; do
    log "--- Итерация $ITERATION ---"
    LOCAL_BEST_SCORE=$BASE_SCORE
    LOCAL_BEST_PARAM=""
    LOCAL_BEST_VAL=""
    
    PARAMS="shared_buffers:$CUR_SHARED_BUFFERS:128:MB work_mem:$CUR_WORK_MEM:2:MB max_connections:$CUR_MAX_CONN:5: effective_cache_size:$CUR_EFFECTIVE_CACHE:256:MB checkpoint_timeout:$CUR_CHECKPOINT:5:min commit_delay:$CUR_COMMIT_DELAY:500: temp_buffers:$CUR_TEMP_BUFFERS:4:MB"
    
    for p in $PARAMS; do
        NAME=$(echo "$p" | cut -d: -f1)
        VAL=$(echo "$p" | cut -d: -f2)
        STEP=$(echo "$p" | cut -d: -f3)
        UNIT=$(echo "$p" | cut -d: -f4)
        
        for SIGN in 1 -1; do
            NEW_VAL=$((VAL + (STEP * SIGN)))
            [ "$NEW_VAL" -lt 0 ] && NEW_VAL=0
            
            OLD_SHARED=$CUR_SHARED_BUFFERS
            OLD_WORK=$CUR_WORK_MEM
            OLD_CONN=$CUR_MAX_CONN
            OLD_CACHE=$CUR_EFFECTIVE_CACHE
            OLD_CHECKPOINT=$CUR_CHECKPOINT
            OLD_COMMIT=$CUR_COMMIT_DELAY
            OLD_TEMP=$CUR_TEMP_BUFFERS
            
            case $NAME in
                "shared_buffers") CUR_SHARED_BUFFERS=$NEW_VAL ;;
                "work_mem") CUR_WORK_MEM=$NEW_VAL ;;
                "max_connections") CUR_MAX_CONN=$NEW_VAL ;;
                "effective_cache_size") CUR_EFFECTIVE_CACHE=$NEW_VAL ;;
                "checkpoint_timeout") CUR_CHECKPOINT=$NEW_VAL ;;
                "commit_delay") CUR_COMMIT_DELAY=$NEW_VAL ;;
                "temp_buffers") CUR_TEMP_BUFFERS=$NEW_VAL ;;
            esac
            
            if ! check_memory; then
                CUR_SHARED_BUFFERS=$OLD_SHARED
                CUR_WORK_MEM=$OLD_WORK
                CUR_MAX_CONN=$OLD_CONN
                CUR_EFFECTIVE_CACHE=$OLD_CACHE
                CUR_CHECKPOINT=$OLD_CHECKPOINT
                CUR_COMMIT_DELAY=$OLD_COMMIT
                CUR_TEMP_BUFFERS=$OLD_TEMP
                continue
            fi
            
            apply_config
            log "Тест: $NAME=$NEW_VAL$UNIT"
            
            SCORE=$(measure_score)
            log "Результат: $SCORE TPS"
            
            if is_greater "$SCORE" "$LOCAL_BEST_SCORE"; then
                LOCAL_BEST_SCORE=$SCORE
                LOCAL_BEST_PARAM=$NAME
                LOCAL_BEST_VAL=$NEW_VAL
                BASE_SCORE=$SCORE
            else
                CUR_SHARED_BUFFERS=$OLD_SHARED
                CUR_WORK_MEM=$OLD_WORK
                CUR_MAX_CONN=$OLD_CONN
                CUR_EFFECTIVE_CACHE=$OLD_CACHE
                CUR_CHECKPOINT=$OLD_CHECKPOINT
                CUR_COMMIT_DELAY=$OLD_COMMIT
                CUR_TEMP_BUFFERS=$OLD_TEMP
                apply_config
            fi
        done
    done
    
    if [ -n "$LOCAL_BEST_PARAM" ]; then
        log "Улучшение: $LOCAL_BEST_PARAM=$LOCAL_BEST_VAL (TPS: $LOCAL_BEST_SCORE)"
        apply_config
    else
        log "Локальный максимум достигнут"
        break
    fi
    
    ITERATION=$((ITERATION + 1))
done

log "=== Завершено ==="
log "Лучший TPS: $BEST_SCORE"