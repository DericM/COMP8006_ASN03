#!/bin/sh
#USER DEFINED SECTION
#############################################################
MAX_LOGIN_ATTEMPTS=3
BLOCK_DURATION_SEC=20  #-1 for forever
SCRIPT_FREQUENCY=5s

#Monitor File Format
#------------Default Fedora
#MONITOR_FILE="/var/log/secure"
#DATE_FORMAT="+%b %e %H:%M:%S"
#FAILED_LOGIN_MARKER=sshd.\*Failed
#------------Generated Testfile
MONITOR_FILE="/root/Desktop/COMP8006_ASN03/testlog"
DATE_FORMAT="+"
FAILED_LOGIN_MARKER=abc123
#############################################################

#Globals
SCRIPT_NAME=$(basename "$0")

#Get logs from the source file that are newer than BLOCK_DURATION_SEC
function get_logs_from_source(){
    if [ $BLOCK_DURATION_SEC -eq -1 ]
    then
        ##get all ssh log entries
        logs=$(grep $FAILED_LOGIN_MARKER $MONITOR_FILE)
    else
        date_option_string="$(date) - ${BLOCK_DURATION_SEC#0} seconds"
        time_marker=$(date -d "$date_option_string" "$DATE_FORMAT")
        awk_comparison="\$0 > \"$time_marker\""
        #get all ssh log entries after designated time
        logs=$(grep $FAILED_LOGIN_MARKER $MONITOR_FILE | awk "$awk_comparison")
    fi
    echo "$logs"
}

#Strips all elements except ip addresses.
function strip_logs_to_ip(){
    ipformat="[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}"
    logs=$(echo "$1" | grep -o "$ipformat")
    echo "$logs"
}

#Sorts and groups ips into matching sets
#Removes sets less than MAX_LOGIN_ATTEMPTS
function sort_group_remove(){
    logs=$(echo "$1"| uniq -cd | awk -v limit=$MAX_LOGIN_ATTEMPTS '$1 > limit{print $2}')
    echo "$logs"
}

function iptables_block_ips(){
    #clear previous rules
    iptables -F
    iptables -X
    for ip in $1
    do
       iptables -A INPUT -s "$ip" -j DROP
    done
}

function check_log_for_failed_logins() {
    logs=$(get_logs_from_source)
    logs=$(strip_logs_to_ip "$logs")
    logs=$(sort_group_remove "$logs")
    echo "Blocked IPs:"
    echo "$logs"
    iptables_block_ips "$logs"
}

function main(){
	repeats=$(60 / $SCRIPT_FREQUENCY)
	for i in {1..20}
	do
		check_log_for_failed_logins
        sleep $SCRIPT_FREQUENCY
	done
    #while true
    #do
    #    check_log_for_failed_logins
    #    sleep $SCRIPT_FREQUENCY
    #done
}
#check_log_for_failed_logins
main
