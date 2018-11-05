#!/bin/bash
###################################################################################
#title           : efm_loadbalance_detach.sh
#description     : Script executes pcp_detach_node command to notify pgpool on node 
#                : removal from pgpool cluster. 
#date            : October 1, 2018
#version         : 1.0
#bash_version    : GNU bash, version 4.2.46(2)-release (x86_64-redhat-linux-gnu)
#author          : Raghavendra Rao(ragavendra.dba@gmail.com)
#
#Mandatory       : SCRIPT REQUIRES PASSWORD LESS EXECUTION. PCPPASS SHOULD BE
#                : CONFIGURED BEFORE CALLING IT. REFER TO THE BLOG ON THE USAGE
###################################################################################
# quit on any error
set -e
set -u

# Set environment variables, so EFM can connect to pgpool cluster and database
# to perform node status checks
#
# EFM variable
#-------------
EFM_HOST_FROM_HOOK=$1                        # argument from EFM fencing hook

# Pgpool cluster connection information
PCP_USER=enterprisedb                 # PCP user name (enterprisedb or postgres)
PCP_PORT=9898                         # PCP port number as in pgpool.conf
PCP_HOST=172.31.40.227                # hostname of Pgpool-II
PGPOOL_PATH=/usr/edb/pgpool3.6/bin    # Pgpool-II installation path
PCPPASSFILE=/var/efm/pcppass          # Path to PCPPASS file
PGPOOL_PORT=9999

# EPAS/PG DB connection information
#-----------------------------------
PGPATH=/usr/edb/as10                 # Path to EDB binaries
PGUSER=enterprisedb
PGPORT=5444
PGHOST=${EFM_HOST_FROM_HOOK}

# Pgpool pcp & db check commands
#-------------------------------
PCP_NODE_COUNT=${PGPOOL_PATH}/pcp_node_count
PCP_NODE_INFO=${PGPOOL_PATH}/pcp_node_info
PCP_DETACH_NODE=${PGPOOL_PATH}/pcp_detach_node
PG_ISREADY=${PGPATH}/bin/pg_isready

export PCPPASSFILE PCP_USER PCP_PORT PCP_HOST PGPOOL_PATH PGPOOL_PORT \
       PGPATH PGUSER PGHOST PGPORT PG_ISREADY \
       PCP_DETACH_NODE PCP_NODE_COUNT 

logfile=/usr/edb/efm-3.2/efm-scripts/efm_detach_script_"`date +"%Y%m%d%H%M%S"`".log

# Print Node status from pool_nodes to log
#-----------------------------------------

print_node_status()
{
   echo -e "\nNode $EFM_HOST_FROM_HOOK Status $2 $3 :">>$logfile
   echo "--------------------------------------------">>$logfile
   ${PGPATH}/bin/psql -h ${PCP_HOST} \
                                  -U ${PCP_USER} \
                                  -p ${PGPOOL_PORT} \
                                  -d template1 \
                                  -c "show pool_nodes;" | awk -v ip="$1" 'NR==1 || NR==2|| $0 ~ ip' >>$logfile
}

#Get Node ID information from show pool_nodes
#---------------------------------------------
get_info_from_pool_nodes()
{
  NO_OF_NODES=$(${PCP_NODE_COUNT} --host=${PCP_HOST} \
                                  --username=${PCP_USER} \
                                  --port=${PCP_PORT} \
                                  --no-password )

  for (( i=0 ; i < ${NO_OF_NODES} ; i++ ))
  do
     exists=$(${PCP_NODE_INFO} --host=${PCP_HOST} \
                               --username=${PCP_USER} \
                               --port=${PCP_PORT} \
                               --no-password ${i} |grep ${1} | wc -l)
     if [[ ${exists} -eq 1 ]]; then
        NODE_ID=${i}
        break
     fi
  done
  echo "$NODE_ID"
}

# Get db running or not
#----------------------
db_status_check()
{
   local val=$(${PG_ISREADY} -h ${PGHOST} \
                             -U ${PGUSER} \
                             -p ${PGPORT} \
                             -t 0 \
                             -d template1 | grep "accepting" | wc -l)
   echo "$val"
}


DB_STATUS=$(db_status_check)

echo "Dettach Node = ( DBNode=Down )">>$logfile
echo "DB Status on $EFM_HOST_FROM_HOOK: `[[ $DB_STATUS -eq 1 ]] && { echo UP; } || { echo DOWN; }`">>$logfile

if [[  ${DB_STATUS} -eq 0 ]]; then
   echo "Performing Detach operation">>$logfile
   print_node_status $EFM_HOST_FROM_HOOK before detach
   EFM_HOOKIP_NODE_ID=$(get_info_from_pool_nodes $EFM_HOST_FROM_HOOK 1)
   echo -e "\nDetaching Node :">>$logfile
   echo "-----------------">>$logfile
   ${PCP_DETACH_NODE} --host=${PCP_HOST} \
                      --username=${PCP_USER} \
                      --port=${PCP_PORT} \
                      --no-password \
                      --verbose \
                      ${EFM_HOOKIP_NODE_ID} >>$logfile

   print_node_status $EFM_HOST_FROM_HOOK after detach
fi

exit 0
