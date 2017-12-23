#!/bin/bash

#The first two lines of my config are:
#api_key="your key here"
#api_secret="your secret here"
#You'll need this for all of the script.
. ~/.rtmcfg

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
  m=$(echo "$rsp" | ./json.sh 2> /dev/null | grep '"rsp","stat"' | cut -f2 )
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
  check=$(curl -s "$api_url?$args&api_sig=$sig" | ./json.sh -b | head -n 1 | cut -f2 | sed 's/"//g')
  echo "$check"
}
#Grabs the timeline. Need for all write requests.
#https://www.rememberthemilk.com/services/api/timelines.rtm
get_timeline () {
  method="rtm.timelines.create"
  args="method=$method&$standard_args"
  sig=$(get_sig "$args")
  timeline=$(curl -s "$api_url?$args&api_sig=$sig" | ./json.sh -b | tail -n1 | cut -f2 | sed 's/"//g')
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
 # last_sync=$(cat $data_dir/last_sync.txt)
  list_id=$1
  args="method=$method&$standard_args&filter=status:incomplete&list_id=$list_id" #&last_sync=$last_sync
  sig=$(get_sig "$args")
  curl -s "$api_url?$args&api_sig=$sig" > "$tasks_json" #data/$list_id.json
 # date -Iseconds > $data_dir/last_sync.txt
}

add_tags () {
  method='rtm.tasks.addTags'
  task="$1"
  tags=$(echo "$hashtags" | cut -d' ' -f2 | sed 's/#//')
  echo "$task_args"
  args="method=$method&$standard_args&timeline=$timeline&$task_args&tags=$tags"
  sig=$(get_sig "$args")
  response=$(wget -q -O - "$api_url?$args&api_sig=$sig")
  status=$(echo "$response" | ./json.sh  | grep '"rsp","stat"' | cut -f2 )
  if [ "$status" = '"ok"' ]; then
    return
  else
    echo "$response"
  fi  
}

tasks_add () {
  method="rtm.tasks.add"
  task="$1"
  name=$(echo "$task" | sed 's/\ #.*$//g') #
  hashtags=$(expr match "$task" '.*\(#.* #.*\)')
  if [[ -z $hashtags ]]; then 
    list_id=39537778
  else
    list_id=$(echo "$hashtags" | cut -d' ' -f1 | sed 's/#//' | xargs -I{} grep "{}" $lists_tsv | cut -f1)
  fi
  args="method=$method&$standard_args&timeline=$timeline&name=$name&parse=1&list_id=$list_id" 
  sig=$(get_sig "$args")
  response=$(wget -q -O - "$api_url?$args&api_sig=$sig")
  status=$(echo "$response" | ./json.sh  | grep '"rsp","stat"' | cut -f2 ) #2> /dev/null
  if [ "$status" = '"ok"' ]; then
    echo "$response"
    return
  else
    echo "$response"
  fi
}

#This will mark a task as complete. And this action can
#be undone if you need.
#https://www.rememberthemilk.com/services/api/methods/rtm.tasks.complete.rtm
tasks_complete () {
  method="rtm.tasks.complete"
  task=$(sed "${1}q;d" $tasks_tsv)
  l_id=$(echo "$task" | cut -f2)
  ts_id=$(echo "$task" | cut -f3)
  t_id=$(echo "$task" | cut -f4)
  args="method=$method&$standard_args&timeline=$timeline&list_id=$l_id&taskseries_id=$ts_id&task_id=$t_id"
  sig=$(get_sig "$args")
  response=$(curl -s "$api_url?$args&api_sig=$sig")
  m=$(echo "$response" | ./json.sh 2> /dev/null | grep '"rsp","stat"' | cut -f2 )
  if [ "$m" = '"ok"' ]; then
    return
  else
    echo "$response"
  fi
}

tasks_delete () {
  method="rtm.tasks.delete"
  task=$(sed "${1}q;d" $tasks_tsv)
  l_id=$(echo "$task" | cut -f2)
  ts_id=$(echo "$task" | cut -f3)
  t_id=$(echo "$task" | cut -f4)
  args="method=$method&$standard_args&timeline=$timeline&$task_args"
  sig=$(get_sig "$args")
  response=$(curl -s "$api_url?$args&api_sig=$sig")
  check $response
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

tasks_postpone () {
  method="rtm.tasks.postpone"
  x=$(grep "item\[$1\]" /tmp/indexed_tasks.csv | sed "s/item\[$1\]=//g" )
  l_id=$(echo "$x" | cut -d',' -f5 | xargs -0 -I{} grep {} /tmp/list-vars.txt | cut -d'=' -f2)
  ts_id=$(echo "$x" | cut -d',' -f3)
  t_id=$(echo "$x" | cut -d',' -f4)
  args="method=$method&$standard_args&timeline=$timeline&list_id=$l_id&taskseries_id=$ts_id&task_id=$t_id"
  sig=$(get_sig "$args")
  check=$(curl -s "$api_url?$args&api_sig=$sig" | jq -r '.rsp | .stat')
  check $check
}

