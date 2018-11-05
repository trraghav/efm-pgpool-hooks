# EFM Load Balancer Hooks Scripts  

EFM 3.2 Load Balancer Hooks (**script.load.balancer.attach & script.load.balancer.detach**) gives great flexibility to control out side modules like connection poolers(or others) while performing switchover or failover or node stop/resume action. In this repository, EFM load balancer hooks script are created to control/modify PgPool Load balancer cluster. These scripts uses PgPool PCP unix command to attach/detach/promote database node in it.

# PreRequisites:

* Bash 
* PgPool Binaries for pcp command utilities  

There are two scripts to handle the PgPool cluster. 

* efm_loadbalancer_attach.sh
* efm_loadbalancer_detach.sh 

### efm_loadbalancer_attach.sh 

This script will be called by EFM **after** performing switchover or failover or standby node resume actions. Hence, this script takes action according to 2 rules to attach or promoate database node in PgPool cluster via PCP command 

* Rule 1: Node should be attached(pcp_attach_node) **only** if database is in Recovery
* Rule 2: Node should be promoted(pcp_promote_node) **only** if database is NOT in Recovery.

### efm_loadbalancer_detach.sh

This script will be called by EFM **before** performing switchover or failover or standby node stop actions. Hence, this script detachs any database node that becomes inactive and updates PgPool cluster via PCP command.

### References

Article posted on the usage of the scripts 

Short video link demonstrating the EFM Load Balancer Hooks scripts in action:







