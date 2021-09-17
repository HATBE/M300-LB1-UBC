#!/bin/bash

# (c) Aaron Gensetter, 2021
# Part from "Ultra Bad Cloud (UBC)"

# Define Variables
JSONFILE="nodes.json"
DBS_IP="10.9.8.101"
DBS_USER="root"
DBS_PW="Password123"

# Define Shell colors
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 6`
RESET=`tput sgr0`

USAGE="${YELLOW}Usage: ${0} <init:deploy [amount]:destroy [node]:start <node>:stop <node>:list>${RESET}"
FRESHJSON="{\"nodes\":{\"dbs\":{\"description\":\"Database Server\",\"ip\":\"${DBS_IP}\",\"ports\":[],\"memory\":3072,\"cpu\":2,\"script\":\"scripts/dbinstall.sh\",\"args\":\"\"}}}"


# check if user is Root user
if [[ $UID -eq 0 ]]; then
    echo "${RED}You cant't be root, to use this script!${RESET}"
    exit 1
fi

####################################################################
# FUNCTIONS
####################################################################
# Check Node
checkNodeStatus () {
    NODE="$1" # Get node from argument 1
    TEST=$(vagrant status ${NODE}) # get the Vagrant status message
    # Define REGEX vars for the status
    REGEX1="${NODE} *running"
    REGEX2="${NODE} *poweroff"
    REGEX3="${NODE} *not *created"

   # Check the Status of the Nodes
    if [[ $TEST =~ $REGEX3 ]]; then 
	    return 3 # not created
    elif [[ $TEST =~ $REGEX2 ]]; then 
	    return 2 # poweroff
    elif [[ $TEST =~ $REGEX1 ]]; then 
	    return 1 # running
    else
	    return 0 # down / not found
    fi
}

# Stop Node
stopNode () {
    NODE=$1 # Get node from argument 1
    checkNodeStatus $NODE
    STATUS=$?
    if [[ $STATUS -ne 0 && $STATUS -ne 2 && $STATUS -ne 3 ]]; then # if node is running
        echo "${GREEN}Stopping node \"${NODE}\"${RESET}"
        vagrant halt $NODE
        exit 0 # success
    else 
        echo "${YELLOW}Node \"${NODE}\" is already stopped or does not exist.${RESET}"
        exit 1 # no success
    fi

}

# Start Node
startNode () {
    NODE=$1 # Get node from argument 1
    checkNodeStatus $NODE
    if [[ $? -eq 1 ]]; then # if node is not running
        echo "${YELLOW}Node \"${NODE}\" is already running.${RESET}"
        exit 1 # no success
    else 
        echo "${GREEN}Starting node \"${NODE}\"${RESET}"
        vagrant up $NODE
        exit 0 # success
    fi
}

# Deploy Nextcloud
deployNode () {
    AMOUNT=$1 # get Loop amount from argument 1
    REGEX='^[1-9]+$'
    if ! [[ $AMOUNT =~ $REGEX ]]; then # check if Amount is a numeric number
        AMOUNT=1 # else, set amount to 0
    fi
    echo "${BLUE}Deploying ${AMOUNT} Nodes${RESET}"
    OUTPUTARRAY=()
    COUNTER=0
    while [ $COUNTER -lt $AMOUNT ]; do # Loop Amount times through deployment
        IP_PREFIX="10.9.8." # make IP prefix
        PORT_PREFIX="80" # make Port Prefix

        NODES=($(jq '.nodes | keys | .[]' $JSONFILE)) # Get all active nodes from json

        NODES=("${NODES[@]:1}") # cut the first (Database Server) from array
        
        if [[ ${NODES[@]} != "" ]]; then # check if any node is in the json file
            NODEARRAY=()
            for string in ${NODES[@]}; do # loop through nodes
                OUTPUT=${string:5:1} # Cut node away and leve number
                NODEARRAY+=("${OUTPUT}") # Add node number to array
            done
            NUM=1
            EXITER=0
            while [[ NUM -eq 1 ]]; do # Loop through until new node number is found
                if [[ $EXITER -eq 0 ]]; then # check if new node number is found
                    NUMBER=$(shuf -i 11-99 -n 1) # Generate random number between 11 and 99
                    for NODE in ${NODEARRAY[@]}; do # Loop through nodes array
                        EXITER=0
                        if [[ $NUMBER -eq $NODE ]]; then # check if random number matches current node number
                            break # does match (BAD)
                        else 
                            EXITER=1 # does not match (GOOD)
                        fi
                    done
                else
                    NUM=0 # Found new not used node number
                fi
            done
        else
            # If no old VM is in the json file, generate a complete new id
            NUMBER=$(shuf -i 11-99 -n 1) # Generate random number between 11 and 99
        fi

        echo "${GREEN}Deploying...${RESET}"
        
        checkNodeStatus dbs
        STATUS=$?
        if [[ STATUS -eq 1 ]]; then # check if Database Server is Online

            # Define variables (Add new found node number to prefixes)
            IP="${IP_PREFIX}${NUMBER}"
            PORT="${PORT_PREFIX}${NUMBER}"
            NODE="node${NUMBER}"

            mysql -h $DBS_IP -u $DBS_USER -p$DBS_PW -e "CREATE DATABASE ${NODE};" # create new db for node
            echo "${GREEN}Created Database for ${NODE}"
            NEWNODE="{
                \"${NODE}\":{
                    \"description\":\"nextcloud frontend\",
                    \"ip\":\"${IP}\",
                    \"ports\":[
                        {
                            \"guest\":80,
                            \"host\":${PORT}
                        }
                    ],
                    \"memory\":1024,
                    \"cpu\":2,
                    \"script\":\"scripts/ncinstall.sh\",
                    \"args\":\"${NODE}\"
                }
            }" # generating new node json object
            echo $(jq --argjson NEWNODE "$NEWNODE" '.nodes += $NEWNODE' $JSONFILE) > $JSONFILE # overwriting  old json file with new informations

            vagrant up $NODE # start new node up

            echo "${GREEN}Deployed ${NODE}${RESET}"

            OUTPUTARRAY+=("${NODE}: http://localhost:${PORT} Username: ${BLUE}admin${RESET} Passwort: ${BLUE}Password123${RESET}") # Add information to Output array
        else
            # DB Server is not Online
            echo "${YELLOW}Warning! DB Server is Offline${RESET}"
            echo "${YELLOW}- Please do ${0} start dbs, or ${0} init.${RESET}"
            echo "${RED}Error! cant create new node"
        fi
        ((COUNTER++)) # increase counter +1
    done
    echo "${GREEN}All Nodes Deployed!${RESET}"
    for NODE in ${OUTPUTARRAY[@]}; do
        echo "${NODE}"
    done
}

# Remove Nextcloud node
destroyNode () {
    NODE2=$1 # Get node from argument 1
    if [[ $NODE != "dbs" ]]; then # check if node is not the Database Server
        checkNodeStatus $NODE2
        STATUS=$?
        if [[ $STATUS -eq 1 || $STATUS -eq 2 || $STATUS -eq 3 ]]; then # check if node exists (cant destroy not existing node)
            echo "${GREEN}destroying ${NODE2}...${RESET}"
            checkNodeStatus "dbs"
            STATUS=$?
            if [[ STATUS -eq 1 ]]; then # Check if the Database server is Online
                mysql -h $DBS_IP -u $DBS_USER -p$DBS_PW -e "DROP DATABASE ${NODE2};" # Remove Database from node
            else
                echo "${YELLOW}DB Server is Offline${RESET}"
                echo "${YELLOW}cant remove ${NODE2}s Databse${RESET}"
            fi

            vagrant destroy $NODE2 # Destroy node
                
            FILTER=".nodes.${NODE2}" # adding node as jq filter
            echo $(jq "del($FILTER)" $JSONFILE) > $JSONFILE # Remove node from json file

            echo "${GREEN}Destroy Successful${RESET}"

        else
            echo "${RED}${NODE2} is not online.${RESET}"
        fi  
    else
        echo "${RED}Can't destroy ${NODE}${RESET}"
    fi
}

####################################################################
# SCRIPT
####################################################################

# Check if user is really in the Vagrant Folder
FOLDER=$(pwd)
read -p "${BLUE}Are you in the correct folder? \"${FOLDER}\". y or n: ${RESET}" ACCEPT # ask user if he is in the right folder
ACCEPT=$(echo $ACCEPT | tr a-z A-Z) # make $accept to uppercase
if [[ "${ACCEPT}" != "Y" ]]; then # check if user accepts
    echo "${RED}you have exited the script${RESET}"
    exit 1 # exit script if user don't says "Y"
fi

# Check if arguments are set
if [[ ${#} -eq 0 ]]; then
    echo "${RED}Not enough arguments. ${USAGE}${RESET}"
    exit 1
fi

# Init -----------------------------------------------------------------------------
if [[ "${1}" ==  "init" ]]; then
    # Only start init things
    echo "${GREEN}Create Init vagrant...${RESET}"
    echo $FRESHJSON > $JSONFILE  # restore nodes json file to defauts (just db Server)
    vagrant destroy -f # destroy all existant 
    checkNodeStatus dbs
    STATUS=$?
    if [[ $STATUS -eq 3 ]] # check if Database is not created
    then
        vagrant up dbs
    fi
# Start -----------------------------------------------------------------------------
elif [[ "${1}" ==  "start" ]]; then
# make option to start only the nodes or the nodes with db
    if [[ $# -ge 2 ]]; then
        startNode $2 # use specified node name to start
    else
        # if no node is given, exit
        echo "${RED}Not enough arguments. ${USAGE}${RESET}"
        exit 1
    fi
# Stop -----------------------------------------------------------------------------
elif [[ "${1}" ==  "stop" ]]; then
    # make option to stop only the nodes or the nodes with db
    if [[ $# -ge 2 ]]; then
        stopNode $2 # use specified node name to stop
    else
        # if no node is given, exit
        echo "${RED}Not enough arguments. ${USAGE}${RESET}"
        exit 1
    fi
# Deploy -----------------------------------------------------------------------------
elif [[ "${1}" ==  "deploy" ]]; then
    if [[ $# -ge 2 ]]; then
        deployNode $2 # if a number is specified, use it
    else 
        deployNode 1 # if no number is specified, use 1
    fi
# Destroy -----------------------------------------------------------------------------
elif [[ "${1}" ==  "destroy" ]]; then
    if [[ $# -ge 2 ]]; then
        # if a node is specified, destroy this node
        destroyNode $2
    else
        # if no args, destoy all
        vagrant destroy -f # Destroy all machines and nodes
        echo $FRESHJSON > $JSONFILE # restore nodes json file to defauts (just db Server)
    fi
# List -----------------------------------------------------------------------------
elif [[ "${1}" ==  "list" ]]; then
    echo "${GREEN}listing items...${RESET}"
    NODES=($(jq '.nodes | keys | .[]' $JSONFILE)) # Select all nodes
    NODES=("${NODES[@]:1}") # cut the first (Database Server) from array
    if [[ ${#NODES[@]} -eq 0 ]]; then
        echo "${RED}No Nodes found!${RESET}"
        exit 1
    fi
    echo "${GREEN}There are ${BLUE}${#NODES[@]}${GREEN} nodes${RESET}" # List amount of nodes
    for NODE in ${NODES[@]}; do # Loop through all elements
        # Get Elements from json file
        DESCRIPTION=$(jq -r ".nodes.${NODE}.description" $JSONFILE)
        IP=$(jq -r ".nodes.${NODE}.ip" $JSONFILE)
        PORT=$(jq -r ".nodes.${NODE}.ports | .[].host" $JSONFILE )
        
        # Get Status of node
        NODE=${NODE:1:6} # cut away '"'
        checkNodeStatus $NODE name
    	STATUS=$?
    	if [[ $STATUS -eq 3 ]]; then 
	        STATUS="${YELLOW}not created${RESET}"
        elif [[ $STATUS -eq 2 ]]; then 
            STATUS="${RED}poweroff${RESET}"
        elif [[ $STATUS -eq 1 ]]; then 
            STATUS="${GREEN}running${RESET}"
        else
            STATUS="${RED}unknown${RESET}"
        fi
        
        # Display Node
        echo "${BLUE}${NODE}${RESET}"
        echo "${BLUE}Status: ${YELLOW}${STATUS}${RESET}"
        echo "${BLUE}Description: ${YELLOW}${DESCRIPTION}${RESET}"
        echo "${BLUE}IP: ${YELLOW}${IP}:${PORT}${RESET}"
        echo "${BLUE}Local: ${YELLOW}http://localhost:${PORT}${RESET}"
        echo "------------------------------------------------------------------"
    done
# Else -----------------------------------------------------------------------------
else
    # Display this message if no argument matches
    echo "${RED}Wrong arguments. ${USAGE}${RESET}"
fi