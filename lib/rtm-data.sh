#!/bin/bash

tmp_files () {
  declare -A tmp
  t=(a b c d e f g h i)

  for tm in "${t[@]}"; do
    tmp[$tm]=$(mktemp data/tassks.XXXXXXXXXX)
  done
}

_lists () {
  tmp1=$(mktemp)
  tmp2=$(mktemp)
  tmp3=$(mktemp)
  ./json.sh < $list_json | tail -n +2 > $tmp1
  list_id=$(grep -e  '"rsp","lists","list",[0-9],"id"' $tmp1 | cut -f2 | sed 's/"//g' > $tmp2) 
  list_name=$(grep -e '"rsp","lists","list",[0-9],"name"' $tmp1 | cut -f2 | sed 's/"//g' > $tmp3)
  paste $tmp2 $tmp3 > data/lists.tsv
  sed -i '/39537782/d' data/lists.tsv
}

list_loop () {
  cmd=$1
  c=0
  while read line; do
  list_id=$(echo "$line" | cut -f1)
    $cmd
  c=$((c+1))
  done < $rtm_lists
}

_tasks () {
  > data/tasks.tsv

  declare -A tmp
  t=(a b c d e f g h i)

  for tm in "${t[@]}"; do
    tmp[$tm]=$(mktemp data/tassks.XXXXXXXXXX)
  done

  all_tasks=$(mktemp)
  ./json.sh < $tasks_json | tail -n +2 > $all_tasks
  list_index=$(grep -e '"taskseries",[0-9],"id"' $all_tasks | cut -f1 | cut -d',' -f4 > ${tmp[a]})
  task_series_id=$(grep -e '"taskseries",[0-9],"id"' $all_tasks | cut -f2 | sed 's/"//g' > ${tmp[b]})
  created=$(grep -e '"taskseries",[0-9],"created"' $all_tasks | cut -f2 | sed 's/"//g' > ${tmp[c]})
  modified=$(grep -e '"taskseries",[0-9],"modified"' $all_tasks | cut -f2 | sed 's/"//g' > ${tmp[d]})
  name=$(grep -e '"taskseries",[0-9],"name"' $all_tasks | cut -f2 | sed 's/"//g' > ${tmp[e]})
  url=$(grep -e '"taskseries",[0-9],"url"' $all_tasks | cut -f2 | sed 's/"//g' > ${tmp[f]})
  task_id=$(grep -e '"task",[0-9],"id"' $all_tasks | cut -f2 | sed 's/"//g' > ${tmp[g]})
  due=$(grep -e '"task",[0-9],"due"' $all_tasks | cut -f2 | sed 's/"//g' > ${tmp[h]})
  priority=$(grep -e '"task",[0-9],"priority"' $all_tasks | cut -f2 | sed 's/"//g' > ${tmp[i]})

  paste ${tmp[@]} > data/tasks.tsv 
  rm -- "${tmp[@]}"
  sed -i '/39537783/d' data/lists.tsv
  mapfile -t list < <(cut -f1 data/lists.tsv)
  while read line; do
    l_index=$(cut -f1)
    sed -i.bak "s/^[0-9]/${list[$l_index]}/" data/tasks.tsv
  done < data/tasks.tsv
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

