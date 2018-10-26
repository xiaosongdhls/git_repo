#!/bin/bash
ts=`/usr/bin/date +%s`;
command_base='/home/work/open-falcon/agent/bin'
rediscli='/opt/redis-4.0.11/src/redis-cli'
step='180'
#endpoint,conn,passwd,tag,max_connection
tags=(
)

metric_connection_alive='redis.connection.alive'
metric_memory_used_percent='redis.memory.used.percent'
metric_memory_used='redis.memory.used.mb'
metric_memory_total='redis.memory.total.mb'
metric_connection_max='redis.connection.max'
metric_connection_current='redis.connection.current'
metric_connection_used_percent='redis.connection.used.percent'
metric_uptime_sec='redis.uptime.sec'

metric_data=""
 for ((i=0; i< ${#tags[*]}; i++))
    do
         endpoint=`echo ${tags[$i]} | awk -F ':' '{print $1}'`
         ip=`echo ${tags[$i]} | awk -F ':' '{print $2}'`
         passwd=`echo ${tags[$i]} | awk -F ':' '{print $3}'`
         redisId=`echo $ip | awk -F '.' '{print $1}'`
         metric_tags=`echo ${tags[$i]} | awk -F ':' '{print $4}'`
         metric_connection_max_value=`echo ${tags[$i]} | awk -F ':' '{print $5}'`
         metric_tags="${metric_tags},id=${redisId}"
         
         #1.connect
         conn_info=`$rediscli -h $ip -a $passwd ping`
         
     if [ "${conn_info}" == "PONG" ];then
                metric_connection_alive_value='1'
                max_memory_get=`$rediscli -h $ip -a $passwd config get maxmemory`
                max_memory=`echo ${max_memory_get} | awk '{print $2}'`

                rm -f /tmp/redis_info.txt
        $rediscli -h $ip -a $passwd info >/tmp/redis_info.txt
        dos2unix /tmp/redis_info.txt
        used_memory=`grep -w used_memory /tmp/redis_info.txt | awk -F ':' '{print $2}'`


                per=$(printf "%.4f" `echo "scale=4;$used_memory/$max_memory"|/bin/bc`)
        metric_memory_used_percent_value=$(printf "%.4f" `echo "$per*100"|/bin/bc`)

                metric_memory_total_value=$(printf "%.2f" `echo "scale=2;$max_memory/1024/1024"|/bin/bc`)
                metric_memory_used_value=$(printf "%.2f" `echo "scale=2;$used_memory/1024/1024"|/bin/bc`)

                #connected_clients
                metric_connection_current_value=`grep -w connected_clients /tmp/redis_info.txt | awk -F ':' '{print $2}'`
                per_client=$(printf "%.4f" `echo "scale=4;$metric_connection_current_value/$metric_connection_max_value"|/bin/bc`)
        metric_connection_used_percent_value=$(printf "%.4f" `echo "$per_client*100"|/bin/bc`)

                #uptime.sec
                metric_uptime_sec_value=`grep -w uptime_in_seconds /tmp/redis_info.txt | awk -F ':' '{print $2}'`
         else
            metric_connection_alive_value='-1'
                metric_memory_used_percent_value='-1'
                metric_memory_used_value='-1'
                metric_memory_total_value='-1'
                metric_connection_used_percent_value='-1'
                metric_connection_current_value='-1'
                metric_uptime_sec_value='-1'
         fi
         
    metric_data=`echo "${metric_data}{\"metric\": \"${metric_connection_alive}\", \"endpoint\": \"${endpoint}\", \"timestamp\": $ts,\"step\": ${step},\"value\": ${metric_connection_alive_value},\"counterType\": \"GAUGE\",\"tags\": \"${metric_tags}\"},\
{\"metric\": \"${metric_memory_used_percent}\", \"endpoint\": \"${endpoint}\", \"timestamp\": $ts,\"step\": ${step},\"value\": ${metric_memory_used_percent_value},\"counterType\": \"GAUGE\",\"tags\": \"${metric_tags}\"},\
{\"metric\": \"${metric_memory_total}\", \"endpoint\": \"${endpoint}\", \"timestamp\": $ts,\"step\": ${step},\"value\": ${metric_memory_total_value},\"counterType\": \"GAUGE\",\"tags\": \"${metric_tags}\"},\
{\"metric\": \"${metric_uptime_sec}\", \"endpoint\": \"${endpoint}\", \"timestamp\": $ts,\"step\": ${step},\"value\": ${metric_uptime_sec_value},\"counterType\": \"GAUGE\",\"tags\": \"${metric_tags}\"},\
{\"metric\": \"${metric_connection_used_percent}\", \"endpoint\": \"${endpoint}\", \"timestamp\": $ts,\"step\": ${step},\"value\": ${metric_connection_used_percent_value},\"counterType\": \"GAUGE\",\"tags\": \"${metric_tags}\"},\
{\"metric\": \"${metric_connection_current}\", \"endpoint\": \"${endpoint}\", \"timestamp\": $ts,\"step\": ${step},\"value\": ${metric_connection_current_value},\"counterType\": \"GAUGE\",\"tags\": \"${metric_tags}\"},\
{\"metric\": \"${metric_connection_max}\", \"endpoint\": \"${endpoint}\", \"timestamp\": $ts,\"step\": ${step},\"value\": ${metric_connection_max_value},\"counterType\": \"GAUGE\",\"tags\": \"${metric_tags}\"},\
{\"metric\": \"${metric_memory_used}\", \"endpoint\": \"${endpoint}\", \"timestamp\": $ts,\"step\": ${step},\"value\": ${metric_memory_used_value},\"counterType\": \"GAUGE\",\"tags\": \"${metric_tags}\"},"`
done

echo [${metric_data%,*}]
