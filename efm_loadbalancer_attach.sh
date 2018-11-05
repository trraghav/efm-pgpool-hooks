#!/bin/bash
###################################################################################
#title           : efm_loadbalance_attach.sh
#description     : Script executes pcp_attach_node/pcp_promote_node command to 
#                : notify pgpool for NEW Master or Attach returning nodes back to  
#                : pgpool cluster. 
#date            : October 27, 2018
#version         : 1.0
#bash_version    : GNU bash, version 4.2.46(2)-release (x86_64-redhat-linux-gnu)
#author          : Raghavendra Rao(ragavendra.dba@gmail.com)
#
#Note: Script runs pcp_* commands. Password less PCP configuration is MUST..
#
###################################################################################
# quit on any error - verify any undefined shell variable
set -e
set -u

# EFM variable
#-------------
EFM_HOST_FROM_HOOK=$1                 # argument from EFM fencing hook

# Pgpool cluster connection information
#--------------------------------------
PCP_USER=enterprisedb                 # PCP user name (enterprisedb or postgres)
PCP_PORT=9898                         # PCP port number as in pgpool.conf
PCP_HOST=172.31.40.227                # hostname of Pgpool-II
PGPOOL_PATH=/usr/edb/pgpool3.6/bin    # Pgpool-II installation path
PGPOOL_PORT=9999
PCPPASSFILE=/var/efm/pcppass          # Path to PCPPASS file

# EPAS/PG DB connection information
#-----------------------------------
PGPATH=/usr/edb/as10                  # Path to EDB binaries
PGUSER=enterprisedb
PGPORT=5444
PGHOST=${EFM_HOST_FROM_HOOK}

# Pgpool pcp & db check commands
#-------------------------------
PCP_NODE_COUNT=${PGPOOL_PATH}/pcp_node_count
PCP_ATTACH_NODE=${PGPOOL_PATH}/pcp_attach_node
PCP_PROMOTE_NODE=${PGPOOL_PATH}/pcp_promote_node
PCP_NODE_INFO=${PGPOOL_PATH}/pcp_node_info
PG_ISREADY=${PGPATH}/bin/pg_isready

export PCPPASSFILE PCP_USER PCP_PORT PCP_HOST PGPOOL_PATH PGPOOL_PORT \
       PGPATH PGUSER PGPORT PG_ISREADY \
       PCP_NODE_INFO PCP_NODE_COUNT PCP_ATTACH_NODE PCP_PROMOTE_NODE

logfile=/usr/edb/efm-3.2/efm-scripts/efm_attach_"`date +"%Y%m%d%H%M%S"`".log


# Print Node status from pool_nodes to log
#-----------------------------------------

print_node_status()
{
   echo "--------------------------------------------">>$logfile
   echo " Node IP: $1 Node ID: $2 $3 :">>$logfile
   echo "--------------------------------------------">>$logfile
   ${PCP_NODE_INFO} -h ${PCP_HOST} -U ${PCP_USER} -p ${PCP_PORT} -w -n ${2} >>$logfile
}

# Get db running or not
#----------------------
db_status_check()
{
   local val=$(${PG_ISREADY} -h ${1} \
                             -U ${PGUSER} \
                             -p ${PGPORT} \
                             -t 0 \
                             -d template1 | grep "accepting" | wc -l)
   echo "$val"
}

#Get Node ID information from show pool_nodes
#---------------------------------------------
get_node_id_using_pcp()
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
                               --no-password ${i} | grep ${1} | wc -l)
     if [[ ${exists} -eq 1 ]]; then
        NODE_ID=${i}
        break
     fi
  done
  echo "$NODE_ID"
}


# Check local node is in Recovery or not
#---------------------------------------

db_recovery_check()
{
   local dbcheck=$(db_status_check ${PGHOST})
   val=x
   if [[ ${dbcheck} -eq 1 ]]; then
       val=$(${PGPATH}/bin/psql -h ${PGHOST} \
                                 -U ${PGUSER} \
                                 -p ${PGPORT} \
                                 -d template1 \
                                 -Atc "select pg_is_in_recovery();")
   fi
   echo "$val"
} 

# pcp_attach_node command
# -----------------------

attach_node_to_pgpool()
{
   echo -e "\nAttaching Node :">>$logfile
   echo "-----------------">>$logfile
   ${PCP_ATTACH_NODE} --host=${PCP_HOST} \
                      --username=${PCP_USER} \
                      --port=${PCP_PORT} \
                      --no-password \
                      --verbose \
                      ${1} >>$logfile
}

attaching_remaining_nodes_to_pgpool()
{
   local tot_nodes=$(${PCP_NODE_COUNT} --host=${PCP_HOST} \
                                       --username=${PCP_USER} \
                                       --port=${PCP_PORT} \
                                       --no-password )
   for (( j=0; j < 2; j++ ))
   do
   for (( i=0 ; i < ${tot_nodes} ; i++ ))
   do
      if [[ ${i} -ne ${1} ]]; then
         node_ip=$(${PCP_NODE_INFO} --host=${PCP_HOST} \
                                          --username=${PCP_USER} \
                                          --port=${PCP_PORT} \
                                          --no-password ${i} | cut -d" " -f1)
         if [[ ! -z ${node_ip} ]]; then
            local node_state=$(db_status_check $node_ip)
            if [[ ${node_state} -eq 1 ]]; then 
               echo -e "\nAttaching Node-ID: ${i} Node-IP: ${node_ip} NodeDBStatus[1-UP/0-DOWN] : ${node_state}">>$logfile 
               attach_node_to_pgpool "${i}"
               print_node_status "${node_ip}" "${i}" "after attach"
            fi
         fi
      fi
   done
   echo -e "\n*** Re-confirming DB Status to attach,due to delay when performing switchover/failover ***">>$logfile
   done
}


# Get Node Id from PgPool cluster & DB status
#--------------------------------------------
EFM_HOOKIP_NODE_ID=$(get_node_id_using_pcp $EFM_HOST_FROM_HOOK)
DB_RECOVERY_STATUS=$(db_recovery_check)


echo "-----------------------------------------------------------">>$logfile
echo "EFM Attaching Nodes Rules :- ">>$logfile
echo "--------------------------">>$logfile
echo "   Rule 1: Node should be attached if DB is in Recovery">>$logfile
echo "   Rule 2: Node should be Promoted if DB is NOT in Recovery">>$logfile
echo "-----------------------------------------------------------">>$logfile
echo "EFM Attaching Node            : $EFM_HOST_FROM_HOOK">>$logfile
echo "DB Recovery Status[True/False]: ${DB_RECOVERY_STATUS} ">>$logfile
echo "Node ID in PgPool Cluster     : ${EFM_HOOKIP_NODE_ID}">>$logfile
echo "-----------------------------------------------------------">>$logfile


# Attach Node if DB node is back as Standby
# -----------------------------------------

if [[ ${DB_RECOVERY_STATUS} == "t" ]]; then
   print_node_status $EFM_HOST_FROM_HOOK ${EFM_HOOKIP_NODE_ID} "before attach"
   attach_node_to_pgpool ${EFM_HOOKIP_NODE_ID}
   print_node_status $EFM_HOST_FROM_HOOK ${EFM_HOOKIP_NODE_ID} "after attach"
fi


# Promote Only if Node is back as Master
# --------------------------------------

if [[ ${DB_RECOVERY_STATUS} == "f" ]]; then
   ${PCP_PROMOTE_NODE} --host=${PCP_HOST} \
                       --username=${PCP_USER} \
                       --port=${PCP_PORT} \
                       --no-password \
                       --verbose \
                       ${EFM_HOOKIP_NODE_ID} >>$logfile
   print_node_status $EFM_HOST_FROM_HOOK ${EFM_HOOKIP_NODE_ID} "after promote" 
   attaching_remaining_nodes_to_pgpool $EFM_HOOKIP_NODE_ID
fi
echo -e "\nNote: Check 'show pool_nodes;' if logs show node status as 'down/waiting'">>$logfile
exit 0

