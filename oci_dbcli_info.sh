#!/bin/bash
#######################################################################################
# Script:       "oci_dbcli_info.sh                                                    #
#                                                                                     #
# Author:       David Sanz Macías                                                     #
#                                                                                     #
#######################################################################################

JOB_NUM=`dbcli list-jobs -j | jq 'length'`
JOB_OK=`dbcli list-jobs -j | jq '[.[] | select(.status=="Success")] | length'`
JOB_KO=`dbcli list-jobs -j | jq '[.[] | select(.status=="Failure")] | length'`
JOB_UNKOWN=$((JOB_NUM - JOB_OK - JOB_KO))

get_Info(){
 curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/metadata/$1
}

get_Extracc_Info_Job(){
 dbcli describe-job -i "$1" -l Verbose | grep "$2" | sed "s/.*$2:[[:space:]]*//"
}

get_Count_Task_Job(){
 dbcli describe-job -i $1 -l Verbose | awk '/Task Name/{flag=1; next} flag' | awk '{print $NF}' | grep $2 | sort | uniq -c | awk '{print $1}'
}

design_report(){
for ((i=0; i<$1; i++)); do
    printf $2
done
}

design_report 100 '+'
printf '\n'
printf '\n'
echo "Check Jobs in "`hostname`" ("$(get_Info privateIP0)") - Shape "$(get_Info dbSystemShape)" - Timezone "$(get_Info timeZone)
printf '\n'
design_report 59 '-'
printf '\n'
echo "| ⏰ Jobs ("${JOB_NUM}") ✅ Success "${JOB_OK}" ❌ Failure "${JOB_KO}" ◉  Others "${JOB_UNKOWN}" |"
design_report 59 '-'
printf '\n'
printf '\n'


if [ "${JOB_KO}" -ne 0 ]; then
echo "Detail Jobs Failure"
design_report 25 '-'
printf '\n'
i=0;
dbcli list-jobs | grep Failure  | awk '{print $1}' | while read -r linea; do
 ((i++))
 percent=$(get_Extracc_Info_Job ${linea} "Progress")
 if [ "$percent" != "NA" ]; then
 percent_n=${percent%\%}
 if [ "$percent_n" -ge 1 ] && [ "$percent_n" -le 25 ]; then
  percent="◔ "${percent}
 fi
 if [ "$percent_n" -ge 26 ] && [ "$percent_n" -le 50 ]; then
  percent="◑ "${percent}
 fi
 if [ "$percent_n" -ge 51 ] && [ "$percent_n" -le 100 ]; then
  percent="◕ "${percent}
 fi
 design_report 3 '·' | sed "s/.*'·':[[:space:]]*//" | tr '·' ' '
 echo ${i}") "$(get_Extracc_Info_Job ${linea} "Description")" ("${percent}") ✖ Failure (" $(get_Count_Task_Job ${linea} "Failure") ")"
 design_report 5 '·' | sed "s/.*'·':[[:space:]]*//" | tr '·' ' '
 echo $(get_Extracc_Info_Job ${linea} "Message")
 design_report 5 '·' | sed "s/.*'·':[[:space:]]*//" | tr '·' ' '
 echo "List Task Failure"
 dbcli describe-job -i ${linea} -l Verbose | awk '/Task Name/{flag=1; next} flag' | grep "Failure" | cut -c1-60 | while read -r linea; do
  design_report 6 '·' | sed "s/.*'·':[[:space:]]*//" | tr '·' ' '
  echo "·"${linea}
 done
fi
done
``
fi

design_report 100 '+'
printf '\n'

