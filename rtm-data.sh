#!/bin/bash

_lists () {
  dump=$(mktemp)
  list_id=$(./json.sh < data/list_of_lists.json | tail -n +2 | grep -e  '/"rsp","lists","list",[0-9],"id"/')#> $dump
  echo "$list_id" 
  #grep -e '"rsp","lists","list",[0-9],"name"'
}

#This grabs the useful data from the json file and
#converts it to a csv.
index_oneTask () {
  list=$(jq -r ".rsp|.tasks|.list[$c]|.id" /tmp/tasks.json| xargs -0 -I{} grep {} /tmp/list-vars.txt | cut -d'=' -f1 )
  series_id=$(jq -r ".rsp|.tasks|.list[$c] |.taskseries|.id" /tmp/tasks.json)
  task_id=$(jq -r ".rsp|.tasks|.list[$c] |.taskseries| .task | .id" /tmp/tasks.json)
  name=$(jq -r ".rsp|.tasks|.list[$c] |.taskseries|.name" /tmp/tasks.json)
  priority=$(jq -r ".rsp|.tasks|.list[$c] |.taskseries|.task|.priority" /tmp/tasks.json)
  due=$(jq -r ".rsp|.tasks|.list[$c]|.taskseries |.task|.due" /tmp/tasks.json)
  due_date=$(date --date="$due" +'%D %H:%M')
  tags=$(jq -r ".rsp|.tasks|.list[$c]|.taskseries |.tags[]|.tag" /tmp/tasks.json)
  echo "$priority,$due_date,$series_id,$task_id,$list,$name" >> /tmp/tasks.csv
}

index_zeroMore () {
  while [ $c1 -lt $y ]
  do
    list=$(jq -r ".rsp|.tasks|.list[$c]|.id" /tmp/tasks.json| xargs -0 -I{} grep {} /tmp/list-vars.txt | cut -d'=' -f1 )
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
}
index_tasks () {
> /tmp/tasks.csv
c=0
  x=$(jq '.rsp|.tasks|.list|length' /tmp/tasks.json)
  while [ $c -lt $x ]
  do
    y=$(jq ".rsp|.tasks|.list[$c]|.taskseries|length" /tmp/tasks.json)
    z=$(jq -r ".rsp|.tasks|.list[$c]|.taskseries|type" /tmp/tasks.json)
    c1=0
    if [ $z == "object" ]
    then
      index_oneTask
    fi
    if [ $z == "array" ]
    then
      index_zeroMore
    fi
  c=$((c+1))
  done
}

#this is the default sorting order. First by priority,
#then by due date.
sort_priority () {
  sort -t',' -k1,2 /tmp/tasks.csv > /tmp/by-priority.csv
}
#you can get it sorted by date if you prefer.
sort_date () {
  sort -t',' -k2,1 /tmp/tasks.csv > /tmp/by-date.csv
}
#this creates an 'item' array, so that we can pick the
#exact task we need to complete.
index_csv () {
> /tmp/indexed_tasks.csv
d=1
  while read line
  do
    echo "$line" | sed "s/^/item\[$d\]=\"/g" | sed "s/\"$//g" >> /tmp/indexed_tasks.csv
  d=$((d+1))
  done < $1
}
#this displays your tasks to stdout looking reasonably,
#I think. I want to add colour.
display_tasks () {
bold=$(tput bold)
normal=$(tput sgr0)
red=$(tput setaf 1)
green=$(tput setaf 2)
orange=$(tput setaf 3)
pink=$(tput setaf 5)
blue=$(tput setaf 6)
white=$(tput setaf 7)
default=$(tput setaf 9)
c=1
  index_csv $1
  while read x
  do
    line=$(echo "$x" | sed "s/item\[$c\]=\"//g")
    pri=$(echo "$line" | cut -d',' -f1)
    due=$(echo "$line" | cut -d',' -f2)
    due_date=$(date --date="$due" +'%b %d %R' | sed 's/00:00//g')
    name=$(echo "$line" | cut -d',' -f6)
    list=$(echo "$line" | cut -d',' -f5)
    tag==$(echo "$line" | cut -d',' -f7)
    if [ $pri == "1" ]
    then
      echo "${white}$c: ${default} ${red}${bold}$name${default}${normal} ${blue}$due_date${default} ${white}#$list${default}"
    elif [ $pri == "2" ]
    then
      echo "${white}$c: ${default} ${orange}${bold}$name${default}${normal} ${blue}$due_date${default} ${white}#$list${default}"
    elif [ $pri == "3" ]
    then
      echo "${white}$c: ${default} ${pink}${bold}$name${default}${normal} ${blue}$due_date${default} ${white}#$list${default}"
    else
      echo "${white}$c: ${default} ${green}$name${default} ${blue}$due_date${default} ${white}#$list${default}"
    fi
  c=$((c+1))
  done < /tmp/indexed_tasks.csv
}

