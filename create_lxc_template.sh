#! /bin/bash

source ./config.sh
source ./lxclib.sh

APT_PACKAGES=("htop" "curl")


USE_TEMPLATE=$(lxcLatestDebianTemplate)
echo "Using template: $USE_TEMPLATE"

result=$(lxcGetContainerType "$CONTAINER_TEMPLATE_ID")
if [ "$result" == "vm" ]; then
    echo "ERROR: Template ID $CONTAINER_TEMPLATE_ID is already in use by a VM."
    exit 1 
fi

if [ "$result" == "lxc" ]; then

    if [ $(lxcIsContainerTemplate "$CONTAINER_TEMPLATE_ID") == "false" ]; then
        echo "The ID $CONTAINER_TEMPLATE_ID is already in use by container: $(lxcGetContainerNameByID "$CONTAINER_TEMPLATE_ID")"
        exit 1 
    else
        echo "The ID $CONTAINER_TEMPLATE_ID is already in use by template: $(lxcGetContainerNameByID "$CONTAINER_TEMPLATE_ID")"
        read -p "Would you like to DELETE the template and continue? (y/N)" DELETE_TEMPLATE
        if [[ $DELETE_TEMPLATE =~ ^[Yy]$ ]]; then
            echo "Deleting template: $(lxcGetContainerNameByID "$CONTAINER_TEMPLATE_ID")"
            pct destroy "$CONTAINER_TEMPLATE_ID"
        else
            exit 0
        fi
    fi
fi

TEMPLATE_PATH=$(pvesm path "$USE_TEMPLATE")
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to get template path for $USE_TEMPLATE"
    exit 1
fi

pct create $CONTAINER_TEMPLATE_ID $TEMPLATE_PATH \
    -hostname DebBase -memory 512 --cores 1 \
    -net0 name=eth0,ip=192.168.1.100/24,gw=192.168.1.1,bridge=vmbr0 \
    -storage services -ssh-public-keys ~/.ssh/authorized_keys \
	--features nesting=1 --unprivileged 1 --cmode console
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create container from template."
    exit 1
fi

pct start $CONTAINER_TEMPLATE_ID
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to start container."
    exit 1
fi

pct exec $CONTAINER_TEMPLATE_ID -- bash -c "apt update -y"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to execute apt update in the container."
    exit 1
fi

pct exec $CONTAINER_TEMPLATE_ID -- bash -c "apt upgrade -y"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to execute apt upgrade in the container."
    exit 1
fi

pct push $CONTAINER_TEMPLATE_ID ./lxc_files/firstboot.sh /usr/local/bin/firstboot.sh
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to push firstboot.sh to the container."
    exit 1
fi

pct exec $CONTAINER_TEMPLATE_ID -- bash -c "chmod +x /usr/local/bin/firstboot.sh"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to chmod firstboot.sh in the container."
    exit 1
fi

pct push $CONTAINER_TEMPLATE_ID ./lxc_files/firstboot.service /etc/systemd/system/firstboot.service
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to push firstboot.service to the container."
    exit 1
fi

pct exec $CONTAINER_TEMPLATE_ID -- bash -c "systemctl enable firstboot.service"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to enable firstboot.service in the container."
    exit 1
fi


for package in "${APT_PACKAGES[@]}"; do
    pct exec $CONTAINER_TEMPLATE_ID -- bash -c "apt install -y $package"
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to install $package in the container."
        exit 1
    fi
done

pct stop $CONTAINER_TEMPLATE_ID
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to stop container."
    exit 1
fi

pct template $CONTAINER_TEMPLATE_ID
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create template."
    exit 1
fi

