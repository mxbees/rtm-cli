#!/bin/bash

#The first two lines of my config are:
#api_key="your key here"
#api_secret="your secret here"
#You'll need this for all of the script.
. $HOME/.rtmcfg
api_url="https://api.rememberthemilk.com/services/rest/"
#I find json easier to work with, but you can remove it
#from here and in the $standard_args variable and you'll 
#get xml back. For json you'll need to install jq, because 
#this script relies heavily on it.
standard_args="api_key=$api_key&format=json&auth_token=$auth_token"
task_args="list_id=$list_id&taskseries_id=$taskseries_id&task_id=$task_id"
#sign requests, pretty much all api calls need to be signed
#https://www.rememberthemilk.com/services/api/authentication.rtm
get_sig ()
{
    echo -n $api_secret$(echo "$1" | tr '&' '\n' | sort | tr -d '\n' | tr -d '=') | md5sum | cut -d' ' -f1
}


check () {
  rsp="$1"
  m=$(echo "$rsp" | "$json" 2> /dev/null | grep '"rsp","stat"' | cut -f2 )
  if [ "$m" != '"ok"' ]; then
    echo "$response"
  else
    return
  fi
}


#authorization
#https://www.rememberthemilk.com/services/api/authentication.rtm
#gets the frob and appends it to your .rtmcfg
get_frob () {
  method="rtm.auth.getFrob"
  args="method=$method&$standard_args"
  sig=$(get_sig "$args")
  x=$(curl -s "$api_url?$args&api_sig=$sig" | jq -r '.rsp | .frob | @text')
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
  token=$(curl -s "$api_url?$args&api_sig=$sig" | jq -r '.rsp | .auth | .token | @text')
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
  check=$(curl -s "$api_url?$args&api_sig=$sig" | "$json" -b | head -n 1 | cut -f2 | sed 's/"//g')
  echo "$check"
}
#Grabs the timeline. Need for all write requests.
#https://www.rememberthemilk.com/services/api/timelines.rtm
get_timeline () {
  method="rtm.timelines.create"
  args="method=$method&$standard_args"
  sig=$(get_sig "$args")
  timeline=$(curl -s "$api_url?$args&api_sig=$sig" | "$json" -b | tail -n1 | cut -f2 | sed 's/"//g')
  echo "$timeline"
}

#Gets a list of lists.
#https://www.rememberthemilk.com/services/api/methods/rtm.lists.getList.rtm
lists_getList () {
  method="rtm.lists.getList"
  args="method=$method&$standard_args"
  sig=$(get_sig "$args")
  curl -s "$api_url?$args&api_sig=$sig"
}

#Grab the tasks and save the json to tmp
#https://www.rememberthemilk.com/services/api/methods/rtm.tasks.getList.rtm
tasks_getList () {
  method="rtm.tasks.getList"
  list_id=39537778 #$1
  args="method=$method&$standard_args&filter=status:incomplete&list_id=$list_id"
  sig=$(get_sig "$args")
  curl -s "$api_url?$args&api_sig=$sig" > "$tasks_json" 
}

add_tags () {
  if [[ ! -z "$tag" ]]; then
    taskseries_id=$(echo "$response" | "$json" | grep 'taskseries","id' | cut -f2 | sed 's/"//g')
    task_id=$(echo "$response" | "$json" | grep 'task","id' | cut -f2 | sed 's/"//g')
    add_tags "$list_id" "$taskseries_id" "$task_id" "$tag"
  fi
  
  method='rtm.tasks.addTags'
  list_id="$1"
  taskseries_id="$2"
  task_id="$3"
  tag="$4"
  echo "$task_args"
  args="method=$method&$standard_args&timeline=$timeline&$task_args&tags=$tags"
  sig=$(get_sig "$args")
  response=$(wget -q -O - "$api_url?$args&api_sig=$sig")
  status=$(echo "$response" | "$json"  | grep '"rsp","stat"' | cut -f2 )
  if [ "$status" = '"ok"' ]; then
    echo "$response"
    return
  else
    echo "$response"
  fi
}

#tasks_add () {
#  method="rtm.tasks.add"
#  task="$1"
#  name=$(echo "$task" | sed 's/\ #.*$//g' | sed 's/\ \+.*$//g') #
#  list=$(echo "$task" | sed 's/\ #.*$//g' | xargs -I{} expr match "{}" '.*+\([a-z].*\)')
#  
#  if [[ -z "$list" ]]; then 
#    list_id=39537778
#  else
#    list_id=$(echo "$list" | xargs -I{} grep "{}" $lists_tsv | cut -f1)
#  fi
#  
#  args="method=$method&$standard_args&timeline=$timeline&name=$name&parse=1&list_id=$list_id" 
#  sig=$(get_sig "$args")
#  response=$(curl -s "$api_url?$args&api_sig=$sig")
#  status=$(echo "$response" | "$json"  | grep '"rsp","stat"' | cut -f2 ) #2> /dev/null
#  tag=$(expr match "$task" '.*\(#[a-z].*\)' | sed 's/\#//g')

#  if [ "$status" = '"ok"' ]; then
#    echo "$response"
#    return
#  else
#    echo "$response"
#    return 1
#  fi
#}

tasks_add () {
  method="rtm.tasks.add"
  task="$1"
  name=$(echo "$task" | sed 's/\ #.*$//g') #
  hashtags=$(expr match "$task" '.*#\([a-z].*\)')
  if [[ -z "$hashtags" ]]; then 
    list_id=39537778
  else
    list_id=$(echo "$hashtags" | xargs -I{} grep "{}" $lists_tsv | cut -f1)
  fi
  args="method=$method&$standard_args&timeline=$timeline&name=$name&parse=1&list_id=$list_id" 
  sig=$(get_sig "$args")
  response=$(wget -q -O - "$api_url?$args&api_sig=$sig")
  m=$(echo "$response" | ./bin/json.sh 2> /dev/null | grep '"rsp","stat"' | cut -f2 )
  if [ "$m" = '"ok"' ]; then
    echo "task added"
    sync_tasks &
    return 
  else
    echo "$response"
  fi
}

tasks_ () {
  method="rtm.tasks.$2"
  task=$(sed "${1}q;d" $tasks_tsv)
  list_id=$(echo "$task" | cut -f2)
  taskseries_id=$(echo "$task" | cut -f3)
  task_id=$(echo "$task" | cut -f4)
  args="method=$method&$standard_args&timeline=$timeline&list_id=$list_id&taskseries_id=$taskseries_id&task_id=$task_id"
  sig=$(get_sig "$args")
  response=$(curl -s "$api_url?$args&api_sig=$sig")
  r=$(echo "$response" | "$json" 2> /dev/null | grep '"rsp","stat"' | cut -f2 )
  if [ "$r" = '"ok"' ]; then
    return
  else
    echo "$response"
    return 1
  fi
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
  response=$(curl -s "$api_url?$bargs&api_sig=$sig")
  check $response
}

tasks_getList
