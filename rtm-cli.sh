#!/bin/bash
  . lib/rtm-api.sh &> /dev/null
  . lib/rtm-data.sh &> /dev/null
  . $PWD/lib/rtm/lib/rtm-api.sh &> /dev/null
  . $PWD/lib/rtm/lib/rtm-data.sh &> /dev/null

lists_json='data/lists.json'
tasks_json='data/tasks.json'
lists_tsv='data/lists.tsv'
tasks_tsv='data/tasks.tsv'
#rtm_lists=$(mktemp)

#does the actions below. i should add a 'help' section.
#Note that it syncs your tasks everytime you add or 
#complete one.
for i in "$@"
do
case $i in
  list|ls)
    if [[ "$2" = '-d' ]]; then
      task_loop 'data/due.tsv'
    elif [[ "$2" = '-p' ]]; then
      task_loop 'data/pri.tsv'
    elif [[ "$2" = "-l" ]]; then
      task_loop 'data/list-sort.tsv'
    else
      task_loop "$tasks_tsv"
    fi
  shift;;  
  add|a)
    tasks_add "$2"
    sync_tasks
  shift
  ;;
  complete|c)
    tasks_complete "$2"
    sync_tasks
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
    tasks_delete
    sync_tasks
  shift
  ;;
  check)
    check_token
  shift
  ;;
esac
done
