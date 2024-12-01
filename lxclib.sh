#! /bin/bash

lxcGetDebianTemplates() {

    local STORAGE_NODES=($(pvesm status --content vztmpl | awk 'NR>1 {print $1}'))
    if [ $? -ne 0 ]; then
        echo "WARNING: Failed to list storage nodes: $result"
        exit 1
    fi  


    # Iterate through the storage nodes, building an array of Debian templates:
    OS_TEMPLATES=()
    for current_storage_node in "${STORAGE_NODES[@]}"; do
        volumes=$(pvesm list "$current_storage_node" 2>/dev/null | awk '$3 == "vztmpl" {print $1}' | grep -E "debian") # | awk -F'/' '{print $NF}')
        if [ $? -eq 0 ]; then
            OS_TEMPLATES+=("${volumes[@]}")
        else
            echo "WARNING: Failed to list volumes from \"$current_storage_node\" storage node!"
            exit 1
        fi
    done

    # return a template per line.
    for template in ${OS_TEMPLATES}; do
        echo "$template"
    done
}


lxcLatestDebianTemplate() {

    # Get the list of locally available Debian templates:
    local OS_TEMPLATES=$(lxcGetDebianTemplates)
    if [ $? -ne 0 ]; then
        echo "WARNING: Failed to get OS templates: $result"
        exit 1
    fi

    # Extract just the version number to a first column, sort by that column, then return the second column.
    printf "%s\n" "${OS_TEMPLATES[@]}"| awk '{match($0, /[0-9]+\.[0-9]+-[0-9]+/); print substr($0,RSTART, RLENGTH) " " $0}' | sort -rV | head -n1 | awk '{print $2}'
}

lxcGetContainerType() {

    local ID=$1

    if [ -z "$ID" ]; then
        echo "WARNING: No ID provided to lxcTemplateIdExists."
        exit 1
    fi

    # Check if ID is used by an LXC container
    if pct list | awk '{print $1}' | grep -q "^$ID$"; then
        echo "lxc"
        exit 0
    fi

    # Check if ID is used by a VM
    if qm list | awk '{print $1}' | grep -q "^$ID$"; then
        echo "vm"
        exit 0
    fi

    echo "none"
}


lxcGetContainerNameByID() {

    local ID=$1

    if [ -z "$ID" ]; then
        echo "ERROR: No ID provided to lxcGetContainerName."
        exit 1
    fi

    # Retrieve the name of the container with the given ID
    pct list | awk -v id="$ID" '$1 == id {print $3}'
}

lxcGetContainerIDByName() {

    local NAME=$1

    if [ -z "$NAME" ]; then
        echo "ERROR: No name provided to lxcGetContainerIDByName."
        exit 1
    fi

    pct list | awk -v name="$NAME" '$3 == name {print $1}'
}

lxcGetContainerStatusByID() {
    local ID=$1

    if [ -z "$ID" ]; then
        echo "ERROR: No ID provided to lxcGetContainerName."
        exit 1
    fi

    # Retrieve the name of the container with the given ID
    pct status "$ID" | awk '{print $2}'
}

lxcIsContainerTemplate() {

    local ID=$1

    if [ -z "$ID" ]; then
        echo "ERROR: No ID provided to lxcIsContainerTemplate."
        exit 1
    fi

    # Check if the container is a template
    if pct config "$ID" | grep -q "^template:"; then
        echo "true"
    else
        echo "false"
    fi
}
