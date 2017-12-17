#!/bin/bash

_lists () {
  tmp1=$(mktemp)
  tmp2=$(mktemp)
  tmp3=$(mktemp)
  ./json.sh < "$lists_json" | tail -n +2 > "$tmp1"
  list_id=$(grep -e  '"rsp","lists","list",[0-9],"id"' "$tmp1" | cut -f2 | sed 's/"//g' > "$tmp2") 
  list_name=$(grep -e '"rsp","lists","list",[0-9],"name"' "$tmp1" | cut -f2 | sed 's/"//g' > "$tmp3")
  paste "$tmp2" "$tmp3" > "$lists_tsv"
  sed -i '/39537782/d' "$lists_tsv"
}

tasks2tsv () {
  > "$tasks_tsv"

  declare -A tmp
  t=(a b c d e f g h i j k)

  for tm in "${t[@]}"; do
    tmp[$tm]=$(mktemp)
  done

  null_filter () {
    echo "$1" 
    echo "$1" 
  }
  all_tasks=$(mktemp)
  ./json.sh < "$tasks_json" | tail -n +2 > "$all_tasks"
  list_id=$(grep -e '"taskseries",[0-9],"id"' "$all_tasks" | cut -f1 | cut -d',' -f4 > "${tmp[a]}")
  task_series_id=$(grep -e '"taskseries",[0-9],"id"' "$all_tasks" | cut -f2 | sed 's/"//g' > "${tmp[b]}")
  task_id=$(grep -e '"task",[0-9],"id"' "$all_tasks" | cut -f2 | sed 's/"//g' > "${tmp[c]}")
  priority=$(grep -e '"task",[0-9],"priority"' "$all_tasks" | cut -f2 | sed 's/"//g' > "${tmp[d]}")
  name=$(grep -e '"taskseries",[0-9],"name"' "$all_tasks" | cut -f2 > "${tmp[e]}")
  due=$(grep -e '"task",[0-9],"due"' "$all_tasks" | cut -f2 | sed 's/""/null/g' | sed 's/"//g' > "${tmp[f]}")
  created=$(grep -e '"taskseries",[0-9],"created"' "$all_tasks" | cut -f2 | sed 's/"//g' > "${tmp[g]}")
  modified=$(grep -e '"taskseries",[0-9],"modified"' "$all_tasks" | cut -f2 | sed 's/"//g' > "${tmp[h]}")
  paste "${tmp[@]}" > "${tmp[j]}" 
  sed -i '/39537783/d' "$lists_tsv"
  mapfile -t list < <(cut -f1 "$lists_tsv")
  while read line; do
    l_index=$(echo "$line" | cut -f1)
    sub=$(echo "${list[$l_index]}")
    echo "$line" | sed "0,/$l_index/s//${list[$l_index]}/" >> "${tmp[k]}"
  done < "${tmp[j]}"
  sort -k 4 -k 6 ${tmp[k]} > "$tasks_tsv"
  rm -- "${tmp[@]}"
}

task_loop () {
  lst=$1
  OLDIFS=$IFS
  IFS=$'\t'
  while read -r task_list task_series_id task_id priority name due created modified; do
    r='[0-9]{4}-[0-9]{2}-[0-9]{2}T05:00:00Z'
    list_name=$(grep "$task_list" "$lists_tsv" | cut -f2)
    if [[ "$due" =~ $r ]]; then
      d=$(date -d "$due" '+%a %b %d, %Y')
      display_task 
    elif [[ "$due" = 'null' ]]; then
      display_task 
    else
      d=$(date -d "$due" '+%c')
      display_task 
    fi
  done < "$lst"
  IFS=$OLDIFS
}

#this is the default sorting order. First by priority,
#then by due date.
by_priority () {
  sort -k 4 "$tasks_tsv" > data/pri.tsv
}
#you can get it sorted by date if you prefer.
by_due_date () {
  sort -k 6 "$tasks_tsv" > data/due.tsv
}



#this displays your tasks to stdout looking reasonably,
#I think. I want to add colour.
display_task () {
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
  case $priority in
    1) echo "${red}${bold}$priority${default}${normal} ${green}$name${default} ${blue}due: ${bold}$d${default}${normal} ${orange}$list_name${default}" ;;
    2) echo "${orange}${bold}$priority${default}${normal} ${green}$name${default} ${blue}due: ${bold}$d${default}${normal} ${orange}#$list_name${default}" ;;
    3) echo "${pink}${bold}$priority${default}${normal} ${green}$name${default} ${blue}due: ${bold}$d${default}${normal} ${orange}#$list_name${default}" ;;
    N) echo "${white}$priority${default}${normal} ${green}$name${default} ${blue}due: ${bold}$d${default}${normal} ${orange}#$list_name${default}" ;;
  esac
}

