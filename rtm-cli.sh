#!/bin/bash
. $PWD/lib/rtm-api.sh
. $PWD/lib/rtm-data.sh

list_json='data/list_of_lists.json'
#tasks_json=$(mktemp)
rtm_lists='data/lists.tsv'
tasks='data/tasks.tsv'
#rtm_lists=$(mktemp)

#does the actions below. i should add a 'help' section.
#Note that it syncs your tasks everytime you add or 
#complete one.
for i in "$@"
do
case $i in
  list|ls)
    if [[ "$2" = '-d' ]]; then
      _by_due_date
      task_loop 'data/due.tsv'
    elif [[ "$2" = '-p' ]]; then
      _by_priority 
      task_loop 'data/pri.tsv'
    else
      tasks2tsv
      task_loop "$tasks"
    fi
  shift;;  
  add|a)
    tasks_add "$2"
     # sync_tasks
     #sort_priority
    #display_tasks /tmp/by-priority.csv
  shift
  ;;
  complete|c)
    tasks_complete "$2"
    sync_tasks
    sort_priority
    display_tasks /tmp/by-priority.csv
  shift
  ;;
  postpone|p)
    tasks_postpone $2
    sync_tasks
    sort_priority
    display_tasks /tmp/by-priority.csv
  shift
  ;;
  sync)
    #sync_tasks
    lists_getList > "$list_json"
    _lists
    list_loop "tasks_getList"
  shift
  ;;
  authorize)
    authenticate
    . ~/.rtmcfg
  shift
  ;;
  date|d)
    sort_date
    display_tasks /tmp/by-date.csv
  shift
  ;;
  check)
    check_token
  shift
  ;;
esac
done
