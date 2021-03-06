#!/bin/bash
. $HOME/.rtmcfg
. $HOME/bin/rtm-cli/lib/rtm-api.sh &> /dev/null
. $HOME/bin/rtm-cli/lib/rtm-data.sh &> /dev/null
lists_json="$data/lists.json"
tasks_json="$data/tasks.json"
lists_tsv="$data/lists.tsv"
tasks_tsv="$data/tasks.tsv"

#does the actions below. i should add a 'help' section.
#Note that it syncs your tasks everytime you add or 
#complete one. sdsdassdsdfsfsdfsdfsdfsdfsdfsfsdfs
for i in "$@"
do
case $i in
  list|ls)
    if [[ "$2" = '-d' ]]; then
      display "$data/due.tsv" _pretty
    elif [[ "$2" = '-p' ]]; then
      display "$data/pri.tsv" _pretty
    elif [[ "$2" = "-l" ]]; then
      display "$data/list-sort.tsv" _pretty
    else
      display "$tasks_tsv" _pretty
    fi
  shift;;  
  add|a)
    g=$(tasks_add "$2")
    if [[ $? = 0 ]];then
      echo "task added"
      sync_tasks &
    else
      echo "$g"
    fi
  shift;;
  com|c)
    q=$(tasks_ "$2" 'complete')
    if [[ $? = 0 ]];then
      #sed -i "${2}d" $tasks_tsv
      echo "task $2 completed :D"
      sync_tasks &
    else
      echo "$q"
    fi
  shift;;
  del|d)
    q=$(tasks_ "$2" 'delete')
    if [[ $? = 0 ]];then
      #sed -i "${2}d" $tasks_tsv
      echo "task $2 deleted"
      sync_tasks &
    else
      echo "$q"
    fi
  shift;;
  postpone|p)
    q=$(tasks_ "$2" 'postpone')
    if [[ $? = 0 ]];then
      #sed -i "${2}d" $tasks_tsv
      echo "task $2 postponed"
      sync_tasks &
    else
      echo "$q"
    fi
  shift;;
  sync)
    sync_tasks
  shift;;
  authorize)
    authenticate
    . ~/.rtmcfg
  shift;;
  check)
    check_token
  shift;;
  test)
    list_loop
  shift;;
esac
done
