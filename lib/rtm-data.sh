#!/bin/bash
. $HOME/.rtmcfg

_lists () {
  tmp1=$(mktemp)
  tmp2=$(mktemp)
  tmp3=$(mktemp)
  "$json" < "$lists_json" | tail -n +2 > "$tmp1"
  list_id=$(grep -e  '"rsp","lists","list",[0-9],"id"' "$tmp1" | cut -f2 | sed 's/"//g' > "$tmp2") 
  list_name=$(grep -e '"rsp","lists","list",[0-9],"name"' "$tmp1" | cut -f2 | sed 's/"//g' > "$tmp3")
  paste "$tmp2" "$tmp3" > "$lists_tsv"
  sed -i '/39537782/d' "$lists_tsv"
}

tasks2tsv () {
  > "$tasks_tsv"
  
  declare -A tmp
  t=(a b c d e f g h i j k l)

  for tm in "${t[@]}"; do
    tmp[$tm]=$(mktemp)
  done

  null_filter () {
    echo "$1" 
    echo "$1" 
  }
  all_tasks=$(mktemp)
  "$json" < "$tasks_json" | tail -n +2 > "$all_tasks"
  list_id=$(grep -E '"taskseries","id"|"taskseries",[0-9]{1,},"id"' "$all_tasks" | cut -f1 | cut -d',' -f4 > "${tmp[a]}")
  task_series_id=$(grep -E '"taskseries","id"|"taskseries",[0-9]{1,},"id"' "$all_tasks" | cut -f2 | sed 's/"//g' > "${tmp[b]}")
  task_id=$(grep -e '"task",[0-9],"id"' "$all_tasks" | cut -f2 | sed 's/"//g' > "${tmp[c]}")
  priority=$(grep -e '"task",[0-9],"priority"' "$all_tasks" | cut -f2 | sed 's/"//g' > "${tmp[d]}")
  name=$(grep -E '"taskseries","name"|"taskseries",[0-9]{1,},"name"' "$all_tasks" | cut -f2 > "${tmp[e]}")
  tag=$(grep -e '"tags","tag",0' "$all_tasks" | cut -f2 | sed 's/"//g' > "${tmp[l]}")
  due=$(grep -e '"task",[0-9],"due"' "$all_tasks" | cut -f2 | sed 's/""/null/g' | sed 's/"//g' > "${tmp[f]}")
  created=$(grep -E 'taskseries","created"|"taskseries",[0-9]{1,},"created"' "$all_tasks" | cut -f2 | sed 's/"//g' > "${tmp[g]}")
  modified=$(grep -E '"taskseries","modified"|"taskseries",[0-9]{1,},"modified"' "$all_tasks" | cut -f2 | sed 's/"//g' > "${tmp[h]}")
  paste "${tmp[@]}" > "${tmp[j]}" 
  sed -i '/39537783/d' "$lists_tsv"
  mapfile -t list < <(grep -e '"rsp","tasks","list",[0-9],"id"' "$all_tasks" | cut -f2 | sed 's/"//g')
  while read line; do
    l_index=$(echo "$line" | cut -f1)
    sub=$(echo "${list[$l_index]}")
    echo "$line" | sed "0,/$l_index/s//${list[$l_index]}/" >> "${tmp[k]}" 
  done < "${tmp[j]}"
  sort -k 5 -k 7 ${tmp[k]} > "$tasks_tsv"
  rm -- "${tmp[@]}"
}

list_loop () {
  lists_getList > "$lists_json"
  _lists
  mapfile -t list < <(cut -f1 $lists_tsv)
  for l in ${list[@]};do
    echo $l
    tasks_getList "$l"
  done
}

index () {
  itmp=$(mktemp)
  g=1
  while read line; do
    if [[ "$g" -lt 10 ]]; then
      echo -e " $g\t$line" >> "$itmp"
    else
      echo -e "$g\t$line" >> "$itmp"
    fi
  g=$((g+1))
  done < "$tasks_tsv"
  cp "$itmp" "$tasks_tsv"
}

#this is the default sorting order. First by priority,
#then by due date.
priority_filter () {
  ptmp=$(mktemp)
  while read a; do
    p=$(echo -e "$a" | cut -f5)
    if [[ "$p" != "N" ]]; then
      echo -e "$a" >> "$ptmp"
    fi
  done < "$tasks_tsv"
  sort -k 5 "$ptmp" > "$data/pri.tsv"
}
#you can get it sorted by date if you prefer.
due_date_filter () {
  dtmp=$(mktemp)
  while read h;do
    v=$(echo -e "$h" | cut -f7)
    r='[0-9]{4}-[0-9]{2}-[0-9]{2}T05:00:00Z'
    if [[ "$v" =~ $r ]]; then
      echo -n ""
    else
      echo -e "$h" >> "$dtmp"
    fi
  done < "$tasks_tsv"
  sort -k 7 "$dtmp" > "$data/due.tsv"
}

by_list () {
  sort -f -k 2 "$tasks_tsv" > "$data/list-sort.tsv"
}

sync_tasks () {
  lists_getList > "$lists_json"
  _lists
  tasks_getList $(grep "All Tasks" "$lists_tsv" | cut -f1)
  tasks2tsv $tasks_json
  index
  due_date_filter
  priority_filter
}

display () {
  lst=$1
  fmt=$2
  OLDIFS=$IFS
  IFS=$'\t'
  while read -r index task_list task_series_id task_id priority name due created modified tags; do
    r='[0-9]{4}-[0-9]{2}-[0-9]{2}T05:00:00Z'
    list_name=$(grep "$task_list" "$lists_tsv" | cut -f2)
    if [[ "$due" =~ $r ]]; then
      due_date=$(date -d "$due" '+%b %d')
      $fmt
    elif [[ "$due" = 'null' ]]; then
      $fmt 
    else
      due_date=$(date -d "$due" '+%b %d %R')
      $fmt 
    fi
  done < "$lst"
  IFS=$OLDIFS
}

_md () {
  case $priority in
    1) echo "*!$priority* $name *$due_date* _#$list_name\_" ;;
    2) echo "*!$priority* $name *$due_date*  _#$list_name\_" ;;
    3) echo "*!$priority* $name *$due_date* _#$list_name\_" ;;
    N) echo "$name *$due_date* _#$list_name" ;;
  esac
}

#this displays your tasks to stdout looking reasonably,
#I think. I want to add colour.
_pretty () {
bold=$(tput bold)
normal=$(tput sgr0)
red=$(tput setaf 1)
green=$(tput setaf 10)
orange=$(tput setaf 208)
pink=$(tput setaf 5)
blue=$(tput setaf 45)
white=$(tput setaf 7)
yellow=$(tput setaf 11)
default=$(tput setaf 220)
purple=$(tput setaf 99)
bright_green=$(tput setaf 10)
amber=$(tput setaf 220)
c=1
  p="${red}${bold}$priority${default}${normal}"
  p1="${red}${bold}$name${default}${normal}"
  p2="${orange}$name${default}"
  p3="${yellow}$name${default}"
  n="${amber}$name${default}"
  d="${blue}${bold}$due_date${default}${normal}"
  l="${purple}$tags${default}"
  h="${bright_green}#${default}"
  i="${pink}$(printf '%02d' $index)${default}"
  case $priority in
    1) echo -e "$i: $p1 $d $h$l" ;;
    2) echo -e "$i: $p2 $d $h$l" ;;
    3) echo -e "$i: $p3 $d $h$l" ;;
    N) echo -e "$i: $n $d $h$l" ;;
  esac
}

