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
  ./json.sh < "$list_json" | tail -n +2 > "$tmp1"
  list_id=$(grep -e  '"rsp","lists","list",[0-9],"id"' "$tmp1" | cut -f2 | sed 's/"//g' > "$tmp2") 
  list_name=$(grep -e '"rsp","lists","list",[0-9],"name"' "$tmp1" | cut -f2 | sed 's/"//g' > "$tmp3")
  paste "$tmp2" "$tmp3" > "$rtm_lists"
  sed -i '/39537782/d' "$rtm_lists"
}

list_loop () {
  cmd=$1
  c=0
  while read line; do
  list_id=$(echo "$line" | cut -f1)
    $cmd
  c=$((c+1))
  done < "$rtm_lists"
}

_json2tsv () {
  > "$list_name"

  declare -A tmp
  t=(a b c d e f g h i j)

  for tm in "${t[@]}"; do
    tmp[$tm]=$(mktemp)
  done

  null_filter () {
    echo "$1" 
    echo "$1" 
  }
  all_tasks=$(mktemp)
  ./json.sh < data/$p.json | tail -n +2 > "$all_tasks"
  list_id=$(grep -e '"taskseries",[0-9],"id"' "$all_tasks" | cut -f1 | cut -d',' -f4 > "${tmp[a]}")
  task_series_id=$(grep -e '"taskseries",[0-9],"id"' "$all_tasks" | cut -f2 | sed 's/"//g' > "${tmp[b]}")
  task_id=$(grep -e '"task",[0-9],"id"' "$all_tasks" | cut -f2 | sed 's/"//g' > "${tmp[c]}")
  priority=$(grep -e '"task",[0-9],"priority"' "$all_tasks" | cut -f2 | sed 's/"//g' > "${tmp[d]}")
  name=$(grep -e '"taskseries",[0-9],"name"' "$all_tasks" | cut -f2 > "${tmp[e]}")
  due=$(grep -e '"task",[0-9],"due"' "$all_tasks" | cut -f2 | sed 's/""/null/g' | sed 's/"//g' > "${tmp[f]}")
  created=$(grep -e '"taskseries",[0-9],"created"' "$all_tasks" | cut -f2 | sed 's/"//g' > "${tmp[g]}")
  modified=$(grep -e '"taskseries",[0-9],"modified"' "$all_tasks" | cut -f2 | sed 's/"//g' > "${tmp[h]}")
  paste "${tmp[@]}" > "${tmp[j]}" 
  #sed -i '/39537783/d' "$rtm_lists"
  mapfile -t list < <(cut -f1 "$rtm_lists")
  while read line; do
    l_index=$(echo "$line" | cut -f1)
    sub=$(echo "${list[$l_index]}")
    echo "$line" | sed "0,/$l_index/s//${list[$l_index]}/" >> "$list_name"
  done < "${tmp[j]}"
  rm -- "${tmp[@]}"
}

_by_list () {
  while read o; do
    #list_name="data/$(echo "$o" | cut -f2 | sed 's/\ //g').txt"
    p=$(echo "$o" | cut -f1)
    list_name="data/$p.tsv"
    _json2tsv
  done < $rtm_lists
}

task_loop () {
  cmd=$1
  OLDIFS=$IFS
  IFS=$'\t'
  while read -r task_list task_series_id task_id priority name due created modified; do
    echo -n "$cmd"
  done < "$tasks"
  IFS=$OLDIFS
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

