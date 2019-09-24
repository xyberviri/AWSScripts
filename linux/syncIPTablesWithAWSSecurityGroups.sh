#!/bin/bash
# syncIPTablesWithAWSSecurityGroups.sh  Copyright (C) 2019  Xyberviri
#    This program comes with ABSOLUTELY NO WARRANTY;
#    This is free software, and you are welcome to redistribute it under certain conditions;
#    GNU GPLv3


afDelim=RULE:
awsRegion=us-east-1

declare -A vpcSubNets
vpcSubNets["vpc-12345678"]="192.168.1.0/24"
vpcSubNets["vpc-12345678"]="192.168.2.0/24"
vpcSubNets["vpc-12345678"]="192.168.3.0/24"
vpcSubNets["vpc-12345678"]="192.168.4.0/24"

#Grab a list of the security groups for this instance via our own meta data
function getSGList {
curl -s http://169.254.169.254/latest/meta-data/security-groups
if [ $? -ne 0 ]; then
    echo "Unable to gather security groups."
	exit 0
fi   
}

#Not Used: Grab a list of all security groups, used for testing script against enviroment.
function getALLSGs {
aws ec2 describe-security-groups --region "${awsRegion}" --query "SecurityGroups[*].GroupName" --output text
}


#Not used, lists managed rules. 
function getManagedRules {
sudo ufw status numbered|grep "$afDelim"
}

#lists managed rules by rule numbered
function getManagedRuleNumbers {
sudo ufw status numbered|grep "$afDelim"|sed 's/^.//;s/^[ \t]*//'|cut -d']' -f1
}

#return sub net for vpc stored in assoc array on line 7+
function getVPCSubNet {
echo ${vpcSubNets[$1]}
}

#return group ID and vpc Id for a specific security group by group name
function getSGInfo {
aws ec2 describe-security-groups --region "${awsRegion}" --filters "Name=group-name,Values=$1" --query "SecurityGroups[*].[GroupId,VpcId]|[]" --output text
}

#return the vpc id by security group id
function getVPCbyGroupID {
aws ec2 describe-security-groups --region "${awsRegion}" --filters "Name=group-id,Values=$1" --query "SecurityGroups[*].VpcId" --output text
}

#return subnet a security group belongs to
function getSGSubNet {
varSGVPC=$(aws ec2 describe-security-groups --region "${awsRegion}" --filters "Name=group-id,Values=$1" --query "SecurityGroups[*].VpcId" --output text)
echo ${vpcSubNets[$varSGVPC]}
}

#return a list of ports mapped to cidr addresses in a security group
function getRulesCIDR {
local varGroupName=($1)
aws ec2 describe-security-groups --region "${awsRegion}" --filters "Name=group-name,Values=${varGroupName}" --query "SecurityGroups[*].IpPermissions[*].{FromPort:FromPort,ToPort:ToPort,IpProtocol:IpProtocol,Accessible_From_IP:IpRanges[*].CidrIp,Accessible_From_SG:UserIdGroupPairs[*].GroupId}|[]" --output json|jq -r '.[]|select(.Accessible_From_IP | length >=1)|"\(.FromPort) \(.ToPort) \(.IpProtocol) \(.Accessible_From_IP[])"'
}

#return a list of ports mapped to nested security groups, will require futher processing.
function getRulesSG {
local varGroupName=($1)
aws ec2 describe-security-groups --region "${awsRegion}" --filters "Name=group-name,Values=${varGroupName}" --query "SecurityGroups[*].IpPermissions[*].{FromPort:FromPort,ToPort:ToPort,IpProtocol:IpProtocol,Accessible_From_IP:IpRanges[*].CidrIp,Accessible_From_SG:UserIdGroupPairs[*].GroupId}|[]" --output json|jq -r '.[]|select(.Accessible_From_SG | length >=1)|"\(.FromPort) \(.ToPort) \(.IpProtocol) \(.Accessible_From_SG[])"'
}

#ports that are null or -1 are invalid and basically either not applicable to a specific protocol or are for the entire range of ports. 
function formatPortString {
if [ "${1}" = "null" ] || [ "${1}" = "-1" ] || [ "${2}" = "null" ] || [ "${2}" = "-1" ]; then
echo " "
else
	if [ $1 -ne $2 ]; then
	echo " --match multiport --dports $1:$2 "
	else
	echo " --dport $1 "
	fi
fi
}

#if its not tcp or udp its either both or icmp, icmp can't be managed by ufw or ip tables
function formatProtocolString {
local varReturnCode=0
	if [ "$1" = "tcp" ] || [ "$1" = "udp" ]; then
	echo " -p $1"
	elif [ "$1" = "-1" ]
	then
		echo " "
	else
		varReturnCode=1
	fi
return $varReturnCode
}


dpkg -s jq &> /dev/null
if [ $? -ne 0 ]; then
    echo "JQ  is NOT installed!"
	exit 0
fi   


###############################################################################
# Main ()                                                                     #
###############################################################################
echo "Syncing ipTables with SecurityGroups."
echo $(date +"%D:%T")

varCommands=()
mySecurityGroups=($(getSGList))

if [ ${#mySecurityGroups[@]} -gt 0 ]; then
	echo "${#mySecurityGroups[@]} SecurityGroups"
	for sG in "${mySecurityGroups[@]}"
	do
	  echo "Proccessing rules for security group: $sG."

	sgInfo=($(getSGInfo ${sG}))
	  echo "Group ID: ${sgInfo[0]}"
	  echo "Parent VPC: ${sgInfo[1]}"
	#  echo $(getVPCbyGroupID ${sgInfo[0]})
	#  echo $(getVPCSubNet ${sgInfo[1]})
		SAVEIFS=$IFS
		IFS=$'\n'
		sgList=($(getRulesCIDR ${sG})) #CIDR rules
		sgList2=($(getRulesSG ${sG}))  #Security Group rules
		IFS=$SAVEIFS
		echo "${#sgList[@]} CIDR rules"
		echo "${#sgList2[@]} SecurityGroup rules"
		echo "Processing CIDR rules"
			for sgRule in "${sgList[@]}"; do
				ruleVars=($sgRule)
				stringPorts=$(formatPortString ${ruleVars[0]} ${ruleVars[1]})
				stringProtocol=$(formatProtocolString ${ruleVars[2]})
				if [ $? -ne 1 ]; then
					echo "Adding rule: (${sgInfo[0]}) ${ruleVars[0]}-${ruleVars[1]}:${ruleVars[2]}:${ruleVars[3]}"
					echo "Command    : sudo iptables -A INPUT -s ${ruleVars[3]}${stringPorts}${stringProtocol} -m state --state NEW -j ACCEPT"
					varCommands=("${varCommands[@]}" "sudo iptables -A INPUT -s ${ruleVars[3]}${stringPorts}${stringProtocol} -m state --state NEW -j ACCEPT")
				else
					echo "Skipping: (${sgInfo[0]}) ${ruleVars[0]}-${ruleVars[1]}:${ruleVars[2]}:${ruleVars[3]} <<<INVALID RULE"
				fi
			done

		echo "Processing SecurityGroup rules"
		
			for sgRule2 in "${sgList2[@]}"; do
				ruleVars2=($sgRule2)
				ruleCIDR=$(getSGSubNet ${ruleVars2[3]})
				stringPorts=$(formatPortString ${ruleVars2[0]} ${ruleVars2[1]})
				stringProtocol=$(formatProtocolString ${ruleVars2[2]})
				if [ $? -ne 1 ]; then
					echo "Adding rule: (${sgInfo[0]}) ${ruleVars2[0]}-${ruleVars2[1]}:${ruleVars2[2]}:${ruleCIDR} SG:${ruleVars2[3]}"
					echo "Command     : sudo iptables -A INPUT -s ${ruleCIDR}${stringPorts}${stringProtocol} -m state --state NEW -j ACCEPT"
					varCommands=("${varCommands[@]}" "sudo iptables -A INPUT -s ${ruleCIDR}${stringPorts}${stringProtocol} -m state --state NEW -j ACCEPT")
				else
					echo  "Skipping: (${sgInfo[0]}) ${ruleVars2[0]}-${ruleVars2[1]}:${ruleVars2[2]}:${ruleCIDR} SG:${ruleVars2[3]} <<<INVALID RULE"
				fi

			done

	done
else
	echo "No Security Groups found"
fi

if [ ${#varCommands[@]} -gt 0 ]; then
	echo "${#varCommands[@]} Firewall Rules"
	for (( i = 0; i < ${#varCommands[@]} ; i++ )); do
		printf "*****Running: ${varCommands[$i]}*****\n"
		eval "${varCommands[$i]}"
	done
else	
	echo "no firewalls rules"
fi

echo "done"

