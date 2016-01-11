#!/bin/bash

. .rtmcfg

#api_key api_secret
api_url="https://api.rememberthemilk.com/services/rest/"
format="json"
standard_args="api_key=$api_key&format=$format&auth_token=$auth_token" #
wget_cmd="wget -q -O -"

#sign requests
get_sig ()
{
    echo -n $api_secret$(echo "$1" | tr '&' '\n' | sort | tr -d '\n' | tr -d '=') | md5sum | cut -d' ' -f1
}

#authorization
get_frob () {
    method="rtm.auth.getFrob"
    args="method=$method&$standard_args"
    sig=$(get_sig "$args")
    x=$($wget_cmd "$api_url?$args&api_sig=$sig" | jq -r '.rsp | .frob | @text')
    echo "frob='$x'" >> .rtmcfg
}

auth_app () {
    auth_url="http://www.rememberthemilk.com/services/auth/"
    perms="delete"
    args="api_key=$api_key&perms=$perms&frob=$frob"
    sig=$(get_sig "$args")
    surf "$auth_url?$args&api_sig=$sig"
}
#H@l0b!umL!0np@ll
get_token () {
    method="rtm.auth.getToken"
    args="method=$method&$standard_args&frob=$frob"
    sig=$(get_sig "$args")
    token=$($wget_cmd "$api_url?$args&api_sig=$sig" | jq -r '.rsp | .auth | .token | @text')
    echo "auth_token='$token'" >> .rtmcfg
}

authenticate () {
    get_frob
    . .rtmcfg
    auth_app
    get_token
}

check_token () {
    method="rtm.auth.checkToken"
    args="method=$method&$standard_args"
    sig=$(get_sig "$args")
    $wget_cmd "$api_url?$args&api_sig=$sig" | jq '.rsp | .stat'
}

get_timeline () {
    method="rtm.timelines.create"
    args="method=$method&$standard_args"
    sig=$(get_sig "$args")
    timeline=$($wget_cmd "$api_url?$args&api_sig=$sig" | jq -r '.rsp|.timeline')
    echo "timeline=$timeline" >> .rtmcfg
}

#api list methods
. .rtmcfg

#lists
lists_getList () {
    method="rtm.lists.getList"
    args="method=$method&$standard_args"
    sig=$(get_sig "$args")
    $wget_cmd "$api_url?$args&api_sig=$sig" > /tmp/lists.json
}

index_lists () {
> /tmp/list-vars.txt
c=0
    x=$(jq '.rsp | .lists | .list | length' /tmp/lists.json)
    while [ $c -lt $x ]
    do
        list_name=$(jq -r ".rsp | .lists | .list[$c] | .name | @text" /tmp/lists.json)
        list_id=$(jq -r ".rsp | .lists | .list[$c] | .id | @text" /tmp/lists.json)
        echo "$list_name=$list_id" | tr -d ' ' >> /tmp/list-vars.txt
    c=$((c+1))
    done 
}

#tasks
tasks_getList () {
. /tmp/list-vars.txt
    method="rtm.tasks.getList"
    args="method=$method&$standard_args&filter=status:incomplete" #
    sig=$(get_sig "$args")
    $wget_cmd "$api_url?$args&api_sig=$sig" > /tmp/tasks.json
}

index_tasks () {
> /tmp/tasks.csv
c=0
    x=$(jq '.rsp|.tasks|.list|length' /tmp/tasks.json)
    while [ $c -lt $x ]
    do
        y=$(jq ".rsp|.tasks|.list[$c]|.taskseries|length" /tmp/tasks.json)
        c1=0
        while [ $c1 -lt $y ]
        do
        list=$(jq -r ".rsp|.tasks|.list[$c]|.id" /tmp/tasks.json| xargs -I{} grep {} /tmp/list-vars.txt | cut -d'=' -f1 )
        series_id=$(jq -r ".rsp|.tasks|.list[$c]|.taskseries[$c1]|.id" /tmp/tasks.json)
        task_id=$(jq -r ".rsp|.tasks|.list[$c]|.taskseries[$c1]| .task | .id" /tmp/tasks.json)
        name=$(jq -r ".rsp|.tasks|.list[$c]|.taskseries[$c1]|.name" /tmp/tasks.json)
        priority=$(jq -r ".rsp|.tasks|.list[$c]|.taskseries[$c1]|.task|.priority" /tmp/tasks.json)
        due=$(jq -r ".rsp|.tasks|.list[$c]|.taskseries[$c1]|.task|.due" /tmp/tasks.json)
        due_date=$(date --date="$due" +'%D %H:%M')
        tags=$(jq -r ".rsp|.tasks|.list[$c]|.taskseries[$c1]|.tags[]|.tag" /tmp/tasks.json)
        echo "$priority,$due_date,$series_id,$task_id,$list,$name" >> /tmp/tasks.csv
        c1=$((c1+1))
        done
    c=$((c+1))
    done
}
sort_priority () {
    sort -t',' -k1 /tmp/tasks.csv > /tmp/by-priority.csv
}

sort_date () {
    sort -t',' -k2 /tmp/tasks.csv > /tmp/by-date.csv
}

index_csv () {
> /tmp/indexed_tasks.csv
d=1
    while read line
    do
        echo "$line" | sed "s/^/item\[$d\]=\"/g" | sed 's/$/"/g' >> /tmp/indexed_tasks.csv
    d=$((d+1))
    done < $1
}
display_tasks () {
c=1
    index_csv $1
    while read line
    do
        pri=$(echo "$line" | cut -d',' -f1 | sed 's/N/\ /g')
        due=$(echo "$line" | cut -d',' -f2)
        due_date=$(date --date="$due" +'%b %d %R' | sed 's/00:00//g')
        name=$(echo "$line" | cut -d',' -f6)
        list=$(echo "$line" | cut -d',' -f5)
        tag==$(echo "$line" | cut -d',' -f7)
        printf "$c: $name $due_date #$list\n"
    c=$((c+1))
    done < /tmp/indexed_tasks.csv
}

#complete task
tasks_complete () {
    method="rtm.tasks.complete"
    x=$(grep "item\[$1\]" /tmp/indexed_tasks.csv | sed "s/item\[$1\]=//g" )
        l_id=$(echo "$x" | cut -d',' -f5 | xargs -I{} grep {} /tmp/list-vars.txt | cut -d'=' -f2)
        ts_id=$(echo "$x" | cut -d',' -f3)
        t_id=$(echo "$x" | cut -d',' -f4)
        args="method=$method&$standard_args&timeline=$timeline&list_id=$l_id&taskseries_id=$ts_id&task_id=$t_id"
    sig=$(get_sig "$args")
    check=$($wget_cmd "$api_url?$args&api_sig=$sig" | jq -r '.rsp | .stat')
    if [ $check == "ok" ]
    then
        echo "Task complete!"
    else
        echo "something bad hapon"
    fi
}
#lists_getList
#tasks_getList
#index_tasks
#index_csv /tmp/tasks.csv
#display_tasks /tmp/tasks.csv
#tasks_complete $1
