# EFM Load Balancer Hooks Scripts  

EFM 3.2 Load Balancer Hooks (**script.load.balancer.attach & script.load.balancer.detach**) gives great flexibility to control out side modules like connection poolers(or others) while performing switchover or failover or node stop/resume action. In this repository, EFM load balancer hooks script are created to control/modify PgPool Load balancer cluster. These scripts uses PgPool PCP unix command to attach/detach/promote database node in it.

# PreRequisites:

* Bash 
* PgPool Binaries for pcp command utilities  

There are two scripts to handle the PgPool cluster. 

* efm_loadbalancer_attach.sh
* efm_loadbalancer_detach.sh 

**Note: Scripts will execute PgPool pcp_* unix commands. Hence, PCP_* commands MUST be configured password-less connection to PgPool Cluster on PCP port 9898**  

### efm_loadbalancer_attach.sh 

This script will be called by EFM **after** performing switchover or failover or standby node resume actions. Hence, this script takes action according to 2 rules to attach or promoate database node in PgPool cluster via PCP command 

* Rule 1: Node should be attached(pcp_attach_node) **only** if database is in Recovery
* Rule 2: Node should be promoted(pcp_promote_node) **only** if database is NOT in Recovery.

### efm_loadbalancer_detach.sh

This script will be called by EFM **before** performing switchover or failover or standby node stop actions. Hence, this script detachs any database node that becomes inactive and updates PgPool cluster via PCP command.

## Important Points 

* Scripts should be edited to update ENVIRONMENT variables of 1) PG/EPAS database 2) PCP User/Port/Host and 3) Script Logging 
* Configure PCP password-less authentication so they are called by EFM user and they are not prompted for password.
* All scripts should be placed in a location where **EFM user ** has access to it.

### Tested Configuration files are available in "test-conffile" directory

Sample configuration files of EPAS, EFM & PgPool files are uploaded. Please go through it as a reference point when implementing it.

#### Sample EFM Attach Script Logging

```
[root@additional-dbs efm-scripts]# more efm_attach_20181027062933.log
-----------------------------------------------------------
EFM Attaching Nodes Rules :-
--------------------------
   Rule 1: Node should be attached if DB is in Recovery
   Rule 2: Node should be Promoted if DB is NOT in Recovery
-----------------------------------------------------------
EFM Attaching Node            : 172.31.41.249
DB Recovery Status[True/False]: f
Node ID in PgPool Cluster     : 0
-----------------------------------------------------------
pcp_promote_node -- Command Successful
--------------------------------------------
 Node IP: 172.31.41.249 Node ID: 0 after promote :
--------------------------------------------
172.31.41.249 5444 2 0.333333 up

Attaching Node-ID: 2 Node-IP: 172.31.34.34 NodeDBStatus[1-UP/0-DOWN] : 1

Attaching Node :
-----------------
pcp_attach_node -- Command Successful
--------------------------------------------
 Node IP: 172.31.34.34 Node ID: 2 after attach :
--------------------------------------------
172.31.34.34 5444 3 0.333333 down

*** Re-confirming DB Status to attach,due to delay when performing switchover/failover ***

Attaching Node-ID: 2 Node-IP: 172.31.34.34 NodeDBStatus[1-UP/0-DOWN] : 1

Attaching Node :
-----------------
pcp_attach_node -- Command Successful
--------------------------------------------
 Node IP: 172.31.34.34 Node ID: 2 after attach :
--------------------------------------------
172.31.34.34 5444 3 0.333333 down

*** Re-confirming DB Status to attach,due to delay when performing switchover/failover ***
Note: Check 'show pool_nodes;' if logs show node status as 'down/waiting'

```

#### Sample EFM Detach script logging

```
[root@masterdb efm-scripts]# more efm_detach_script_20181027062829.log
Dettach Node = ( DBNode=Down )
DB Status on 172.31.34.34: DOWN
Performing Detach operation

Node 172.31.34.34 Status before detach :
--------------------------------------------

Detaching Node :
-----------------
pcp_detach_node -- Command Successful

Node 172.31.34.34 Status after detach :
--------------------------------------------
```



## References

Read the article for configuration.

[www.raghavt.com](https://www.raghavt.com/)  

Short video link demonstrating the integration of EFM & PgPool.

[https://youtu.be/pgZJiXa3SoY](https://youtu.be/pgZJiXa3SoY)







