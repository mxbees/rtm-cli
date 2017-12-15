#!/bin/bash


#does the actions below. i should add a 'help' section.
#Note that it syncs your tasks everytime you add or 
#complete one.
for i in "$@"
do
case $i in
  list|ls)
    sync_tasks
    sort_priority
    display_tasks /tmp/by-priority.csv
  shift
  ;;
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
