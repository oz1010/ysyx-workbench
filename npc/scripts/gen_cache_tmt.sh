#!/bin/bash

set -e

data_file=${1:-$NPC_HOME/datas/icache/npc-inst.bin}
sim_tool=$NPC_HOME/tools/cachesim/build/cachesim
sim_args="-t flash,4,2466.0 -t sdram,4,149.6 -s"
cache_args=(
#   w   n   m
    1   0   2
    2   0   2
    4   0   2
    8   0   2
    1   1   2
    2   1   2
    4   1   2
    8   1   2
    1   2   2
    2   2   2
    4   2   2
    8   2   2
    1   3   2
    2   3   2
    4   3   2
    8   3   2
    1   4   2
    2   4   2
    4   4   2
    8   4   2
    
    1   0   3
    2   0   3
    4   0   3
    8   0   3
    1   1   3
    2   1   3
    4   1   3
    8   1   3
    1   2   3
    2   2   3
    4   2   3
    8   2   3
    1   3   3
    2   3   3
    4   3   3
    8   3   3
    1   4   3
    2   4   3
    4   4   3
    8   4   3
    
    1   0   4
    2   0   4
    4   0   4
    8   0   4
    1   1   4
    2   1   4
    4   1   4
    8   1   4
    1   2   4
    2   2   4
    4   2   4
    8   2   4
    1   3   4
    2   3   4
    4   3   4
    8   3   4
    1   4   4
    2   4   4
    4   4   4
    8   4   4
    
    1   0   5
    2   0   5
    4   0   5
    8   0   5
    1   1   5
    2   1   5
    4   1   5
    8   1   5
    1   2   5
    2   2   5
    4   2   5
    8   2   5
    1   3   5
    2   3   5
    4   3   5
    8   3   5
    1   4   5
    2   4   5
    4   4   5
    8   4   5
)

function process() {
    local mem_type=""
    local mem_value=""
    local w=$1
    local n=$2
    local m=$3
    local result="$4"
    
    OLD_IFS="$IFS"
    IFS=$'\n'  # 设置换行符为分隔符
    for line in `echo "$result" | grep -E '(^|[[:space:]])[[:alnum:]]+[[:space:]]+TMT:'`; do
        if [[ "$line" =~ ([[:alnum:]_-]+)[[:space:]]+TMT:[[:space:]]+([0-9.]+) ]]; then
            # echo -n "${BASH_REMATCH[1]}:${BASH_REMATCH[2]} "
            mem_type="${mem_type}${BASH_REMATCH[1]} "
            mem_value="${mem_value}${BASH_REMATCH[2]} "
        fi
    done
    IFS="$OLD_IFS"

    # echo
    echo -ne "$w $n $m \t| $mem_type \t| $mem_value\n"
    # printf "%32s %+32s\n" "$mem_type $mem_value"
}

pushd $NPC_HOME >/dev/null

make cachesim >/dev/null
# make run_cachesim mainargs="datas/icache/npc-inst.bin -t flash,4,2466.0 -t sdram,4,149.6 -s -c 1,1,4"

echo -ne "w n m \t| mem type \t| mem TMT\n"
for ((i=0; i<${#cache_args[@]}; i+=3)); do
    w=${cache_args[i]}
    n=${cache_args[i+1]}
    m=${cache_args[i+2]}
    # echo "组 $((i/3+1)): w=$w, n=$n, m=$m"
    result=$($sim_tool $data_file $sim_args -c $w,$n,$m)
    process $w $n $m "$result"
    # echo $sim_tool $data_file $sim_args -c $w,$n,$m
done

popd &>/dev/null

