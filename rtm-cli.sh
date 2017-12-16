#!/bin/bash
. lib/rtm-api.sh
. lib/rtm-data.sh

#list_json=$(mktemp)
list_json='data/list_of_lists.json'
#tasks_json='data/all-tasks.json'
tasks_json=$(mktemp)
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
    list_loop "tasks_getList"
    _tasks
    task_loop
  shift;;  
  lsl)
    lists_getList #> "$list_json"
    list_loop _lists
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
    sync_tasks
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
