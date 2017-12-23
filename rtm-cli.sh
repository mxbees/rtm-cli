#!/bin/bash
  . lib/rtm-api.sh &> /dev/null
  . lib/rtm-data.sh &> /dev/null
  . $PWD/lib/rtm/lib/rtm-api.sh &> /dev/null
  . $PWD/lib/rtm/lib/rtm-data.sh &> /dev/null
json='./json.sh'
lists_json='data/lists.json'
tasks_json='data/tasks.json'
lists_tsv='data/lists.tsv'
tasks_tsv='data/tasks.tsv'
#rtm_lists=$(mktemp)

#does the actions below. i should add a 'help' section.
#Note that it syncs your tasks everytime you add or 
#complete one. sdsdassdsdfsfsdfsdfsdfsdfsdfsfsdfs
for i in "$@"
do
case $i in
  list|ls)
    if [[ "$2" = '-d' ]]; then
      display 'data/due.tsv' _pretty
    elif [[ "$2" = '-p' ]]; then
      display 'data/pri.tsv' _pretty
    elif [[ "$2" = "-l" ]]; then
      display 'data/list-sort.tsv' _pretty
    else
      display "$tasks_tsv" _pretty
    fi
  shift;;  
  add|a)
    g=$(tasks_add "$2")
    if [[ $? = 0 ]];then
      echo "task added"
      list_id=$(echo "$g" | "$json" | grep 'list","id' | cut -f2 | sed 's/"//g')
      taskseries_id=$(echo "$g" | "$json" | grep 'taskseries","id' | cut -f2 | sed 's/"//g')
      task_id=$(echo "$g" | "$json" | grep 'task","id' | cut -f2 | sed 's/"//g')
      add_tags "$2"
      #sync_tasks #&
    else
      echo "$g"
    fi
  shift
  ;;
  com|c)
    q=$(tasks_complete "$2")
    if [[ $? = 0 ]];then
      sed -i "${2}d" $tasks_tsv
      echo "task $2 completed :D"
    else
      echo "$q"
    fi
  shift
  ;;
  test)
    list_loop
  shift;;
  postpone|p)
    tasks_postpone $2
    sync_tasks
    sort_priority
    display_tasks /tmp/by-priority.csv
  shift
  ;;
  sync)
    sync_tasks
  shift
  ;;
  authorize)
    authenticate
    . ~/.rtmcfg
  shift
  ;;
  del|d)
    tasks_delete "$2"
    sync_tasks
  shift
  ;;
  check)
    check_token
  shift
  ;;
  bls)
  if [[ "$2" = '-d' ]]; then
    display 'data/due.tsv' _md
  elif [[ "$2" = '-p' ]]; then
    display 'data/pri.tsv' _md
  elif [[ "$2" = "-l" ]]; then
    display 'data/list-sort.tsv' _md
  else
    display "$tasks_tsv" _md
  fi
  shift;;
esac
done
