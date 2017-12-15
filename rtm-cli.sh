#!/bin/bash
#The first two lines of my config are:
#api_key="your key here"
#api_secret="your secret here"
#You'll need this for all of the script.
. ~/.rtmcfg
data_dir='/home/nina/Documents/code/halp_me_bot/data'
api_url="https://api.rememberthemilk.com/services/rest/"
#I find json easier to work with, but you can remove it
#from here and in the $standard_args variable and you'll 
#get xml back. For json you'll need to install jq, because 
#this script relies heavily on it.
format="json"
standard_args="api_key=$api_key&format=$format&auth_token=$auth_token"
#You could easily swap this out for `curl -s` if you want.
#I prefer wget for no principled reason.
wget_cmd="wget -q -O -"

#sign requests, pretty much all api calls need to be signed
#https://www.rememberthemilk.com/services/api/authentication.rtm
get_sig ()
{
  echo -n $api_secret$(echo "$1" | tr '&' '\n' | sort | tr -d '\n' | tr -d '=') | md5sum | cut -d' ' -f1
}

check () {
  if [ "$1" != 'ok' ]; then
    echo "$response"
  fi
}


#authorization
#https://www.rememberthemilk.com/services/api/authentication.rtm
#gets the frob and appends it to your .rtmcfg
get_frob () {
  method="rtm.auth.getFrob"
  args="method=$method&$standard_args"
  sig=$(get_sig "$args")
  x=$($wget_cmd "$api_url?$args&api_sig=$sig" | jq -r '.rsp | .frob | @text')
  echo "frob='$x'" >> ~/.rtmcfg
}
#builds the URL for giving permissison for the app to 
#access your account. 
auth_app () {
  auth_url="http://www.rememberthemilk.com/services/auth/"
  perms="delete"
  args="api_key=$api_key&perms=$perms&frob=$frob"
  sig=$(get_sig "$args")
  x-www-browser "$auth_url?$args&api_sig=$sig"
}
#Once the window/tab/whatever is closed, this method is
#called to get the all important auth_token. Which is
#then appended to your .rtmcfg
get_token () {
  method="rtm.auth.getToken"
  args="method=$method&$standard_args&frob=$frob"
  sig=$(get_sig "$args")
  token=$($wget_cmd "$api_url?$args&api_sig=$sig" | jq -r '.rsp | .auth | .token | @text')
  echo "auth_token='$token'" >> ~/.rtmcfg
}

#bundles all the above steps
authenticate () {
  get_frob
  . .rtmcfg
  auth_app
  get_token
}
#this is to check if your auth_token is valid
#use this to troubleshoot if the authentication isn't working.
check_token () {
  method="rtm.auth.checkToken"
  args="method=$method&$standard_args"
  sig=$(get_sig "$args")
  check=$($wget_cmd "$api_url?$args&api_sig=$sig" | ./jsonsh/JSON.sh -b | head -n 1 | cut -f2 | sed 's/"//g')
  check $check
}
#Grabs the timeline. Need for all write requests.
#https://www.rememberthemilk.com/services/api/timelines.rtm
get_timeline () {
  method="rtm.timelines.create"
  args="method=$method&$standard_args"
  sig=$(get_sig "$args")
  timeline=$($wget_cmd "$api_url?$args&api_sig=$sig" | ./jsonsh/JSON.sh -b | tail -n1 | cut -f2 | sed 's/"//g')
  echo "$timeline"
}

#Gets a list of lists.
#https://www.rememberthemilk.com/services/api/methods/rtm.lists.getList.rtm
lists_getList () {
  method="rtm.lists.getList"
  args="method=$method&$standard_args"
  sig=$(get_sig "$args")
  $wget_cmd "$api_url?$args&api_sig=$sig" #> /tmp/lists.json
}
#This matches the list name with its ID.
index_lists () {
> /tmp/list-vars.txt
c=0
  x=$(jq '.rsp | .lists | .list | length' /tmp/lists.json)
  while [ $c -lt $x ]
  do
    list_name=$(jq -r ".rsp | .lists | .list[$c] | .name | @text" /tmp/lists.json)
    list_id=$(jq -r ".rsp | .lists | .list[$c] | .id | @text" /tmp/lists.json)
    echo "$list_name=$list_id" | tr -d ' ' >> /tmp/list-vars.txt
  c=$((c+1))
  done 
}

#Grab the tasks and save the json to tmp
#https://www.rememberthemilk.com/services/api/methods/rtm.tasks.getList.rtm
tasks_getList () {
  method="rtm.tasks.getList"
  last_sync=$(cat $data_dir/last_sync.txt)
  
  while read line; do
    list_id=$(echo $line | cut -d',' -f1)
    args="method=$method&$standard_args&filter=status:incomplete&list_id=$list_id&last_sync=$last_sync"
    sig=$(get_sig "$args")
    $wget_cmd "$api_url?$args&api_sig=$sig"
  done < $data_dir/rtm_lists.csv
  
  date -Iseconds > $data_dir/last_sync.txt
}
tasks_getList
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
#Bundle the above four steps for one sync.
sync_tasks () {
  lists_getList
  index_lists
  tasks_getList
  index_tasks
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

#This will mark a task as complete. And this action can
#be undone if you need.
#https://www.rememberthemilk.com/services/api/methods/rtm.tasks.complete.rtm
tasks_complete () {
  method="rtm.tasks.complete"
  x=$(grep "item\[$1\]" /tmp/indexed_tasks.csv | sed "s/item\[$1\]=//g" )
  l_id=$(echo "$x" | cut -d',' -f5 | xargs -0 -I{} grep {} /tmp/list-vars.txt | cut -d'=' -f2)
  ts_id=$(echo "$x" | cut -d',' -f3)
  t_id=$(echo "$x" | cut -d',' -f4)
  args="method=$method&$standard_args&timeline=$timeline&list_id=$l_id&taskseries_id=$ts_id&task_id=$t_id"
  sig=$(get_sig "$args")
  check=$($wget_cmd "$api_url?$args&api_sig=$sig" | jq -r '.rsp | .stat')
  check $check
}
#Add a task. For the sake of... simplicity, its usually
#best to always add to a specific list. Something wonky
#happens atm if there are tasks in the Inbox.
#https://www.rememberthemilk.com/services/api/methods/rtm.tasks.add.rtm
tasks_setPriority () {
  smethod="rtm.tasks.setPriority"
  p=$1
  data=$2
  ts_id=$(echo "$data" | jq -r '.rsp | .list | .taskseries | .id')
  t_id=$(echo "$data" | jq -r '.rsp | .list | .taskseries | .task | .id')
  bargs="method=$smethod&$standard_args&timeline=$timeline&list_id=$l_id&taskseries_id=$ts_id&task_id=$t_id&priority=$p"
  sig=$(get_sig "$bargs")
  response=$($wget_cmd "$api_url?$bargs&api_sig=$sig")
  check=$( echo "$response" | jq -r '.rsp | .stat')
  check $check
}
tasks_add () {
  method="rtm.tasks.add"
  p=$(echo $1 | sed 's/\ .*//g' | sed 's/!//g')
  name=$(echo "$1" | sed 's/^![1-9]\ //g' | sed 's/\ #[a-z]*$//g')
  l_id=$(echo "$1" | sed 's/^.*#//g' | xargs -I{} grep {} /home/nina/Documents/code/halp_me_bot/data/rtm_lists.csv | cut -d',' -f1)
  args="method=$method&$standard_args&timeline=$timeline&name=$name&list_id=$l_id&parse=1" #
  sig=$(get_sig "$args")
  response=$($wget_cmd "$api_url?$args&api_sig=$sig")
  check=$(echo "$response" | jq -r '.rsp | .stat')
  check $check
  if [ $p == "1" -o $p == "2" -o $p == "3" ]
  then
    tasks_setPriority "$p" "$response"
  fi
}

tasks_postpone () {
  method="rtm.tasks.postpone"
  x=$(grep "item\[$1\]" /tmp/indexed_tasks.csv | sed "s/item\[$1\]=//g" )
  l_id=$(echo "$x" | cut -d',' -f5 | xargs -0 -I{} grep {} /tmp/list-vars.txt | cut -d'=' -f2)
  ts_id=$(echo "$x" | cut -d',' -f3)
  t_id=$(echo "$x" | cut -d',' -f4)
  args="method=$method&$standard_args&timeline=$timeline&list_id=$l_id&taskseries_id=$ts_id&task_id=$t_id"
  sig=$(get_sig "$args")
  check=$($wget_cmd "$api_url?$args&api_sig=$sig" | jq -r '.rsp | .stat')
  check $check
}

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
