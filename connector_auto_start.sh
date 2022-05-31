#/bin/bash
######################### VARIABLES ###########################

SERVER_NAME=<kafka_server>
USERNAME=<user>
PASSWORD=<password>

############################################# CONNECTOERS SECTION ############################################################
echo Starting at $(date +'%Y/%m/%d %H:%M:%S')
FAILED_CONNECTOR=`curl --user "$USERNAME:$PASSWORD" -s https://$SERVER_NAME:8083/connectors| jq '.[]'| \
xargs -I{connector_name} curl --user  "$USERNAME:$PASSWORD" -s https://$SERVER_NAME:8083/connectors/{connector_name}"/status"| \
jq -c -M '[.name,.connector.state]|join(":|:")'| column -s : -t| sed 's/\"//g'| sort | grep FAILED | awk '{ print $1 }' | wc -l`

echo "Connector Failed state count - $FAILED_CONNECTOR"
echo  " "
if [ $FAILED_CONNECTOR -gt 0 ]
then
  echo "Failed Connectors Name :"
  curl --user "$USERNAME:$PASSWORD" -s https://$SERVER_NAME:8083/connectors| jq '.[]'| \
  xargs -I{connector_name} curl --user  "$USERNAME:$PASSWORD" -s https://$SERVER_NAME:8083/connectors/{connector_name}"/status"| \
  jq -c -M '[.name,.connector.state]|join(":|:")'| column -s : -t| sed 's/\"//g'| sort | grep FAILED | awk '{ print $1 }'
else
  echo " "
fi

echo  " "

if [ $FAILED_CONNECTOR -gt 0 ]
then
   echo "Restarting Failed Connector"
   curl --user "$USERNAME:$PASSWORD" -s https://$SERVER_NAME:8083/connectors| jq '.[]'| \
   xargs -I{connector_name} curl --user "$USERNAME:$PASSWORD" -s https://$SERVER_NAME:8083/connectors/{connector_name}"/status"| \
   jq -c -M '[.name,.connector.state]|join(":|:")'| column -s : -t| sed 's/\"//g'| sort | grep FAILED | awk '{ print $1 }' | \
   xargs -I{failed_connector_name} curl --user "$USERNAME:$PASSWORD" -X POST https://$SERVER_NAME:8083/connectors/{failed_connector_name}/restart
   echo "Failed Connector restarted Successfully"
else
   echo -e "All Connectors are in running state \U0001F642"
fi
############################################### TASK SECTION #################################################################

FAILED_CONNECTOR_TASKS=`curl --user "$USERNAME:$PASSWORD" -s https://$SERVER_NAME:8083/connectors| jq '.[]'| \
xargs -I{connector_name} curl --user "$USERNAME:$PASSWORD" -s https://$SERVER_NAME:8083/connectors/{connector_name}"/status"| \
jq -c -M '[.name,.tasks[].state]|join(":|:")'| column -s : -t| sed 's/\"//g'| sort | grep FAILED| awk '{ print $1 }' | wc -l`
echo "==============================================="
echo "Task Failed state count - $FAILED_CONNECTOR_TASKS"
echo  " "
if [ $FAILED_CONNECTOR -gt 0 ]
then
    echo "Connector Name having failed task :"
    curl --user "$USERNAME:$PASSWORD" -s https://$SERVER_NAME:8083/connectors| jq '.[]'| \
    xargs -I{connector_name} curl --user "$USERNAME:$PASSWORD" -s https://$SERVER_NAME:8083/connectors/{connector_name}"/status"| \
    jq -c -M '[.name,.tasks[].state]|join(":|:")'| column -s : -t| sed 's/\"//g'| sort | grep FAILED | awk '{ print $1 }'
else
   echo " "
fi

echo  " "
if [ $FAILED_CONNECTOR_TASKS -gt 0 ]
then
   echo "Restarting Failed Tasks under Connector"
   curl --user "$USERNAME:$PASSWORD" -s https://$SERVER_NAME:8083/connectors?expand=status | \
   jq -c -M 'map({name: .status.name } +  {tasks: .status.tasks}) | .[] | {task: ((.tasks[]) + {name: .name})}  | select(.task.state=="FAILED") | {name: .task.name, task_id: .task.id|tostring} | ("/connectors/"+ .name + "/tasks/" + .task_id + "/restart")' | xargs -I{connector_and_task} curl --user "$USERNAME:$PASSWORD" -X POST https://$SERVER_NAME:8083\{connector_and_task\}
   echo "Failed Task restarted Successfully under Connector"
else
   echo -e "All Tasks are running under Connectors \U0001F642"
fi
echo "==============================================="
