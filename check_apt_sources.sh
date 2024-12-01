#! /bin/bash


APT_SOURCES="/etc/apt/sources.list"

VERSION_CODENAME=$(grep VERSION_CODENAME /etc/os-release | awk -F= '{print $2}')

# Check our apt repositories first for expected entries:
echo "Checking apt sources..."
SUGGESTIONS=()
if ! grep -q "non-free" $APT_SOURCES; then
    SUGGESTIONS+=("add non-free")
fi
if ! grep -q "non-free-firmware" $APT_SOURCES; then
    SUGGESTIONS+=("add non-free-firmware")
fi
if ! grep -q "/debian/pve" $APT_SOURCES; then
    SUGGESTIONS+=("add pve repository for kernel headers")
fi



# If we have suggestions, print them and ask the user if they want to edit the file:
if [ ${#SUGGESTIONS[@]} -gt 0 ]; then
    echo "It is recommended to make the following changes to your apt sources:"
    for SUGGESTION in "${SUGGESTIONS[@]}"; do
        echo "  * $SUGGESTION"
    done
    echo ""

    echo "Proxmox package repository information should be available at:"
    echo "  https://pve.proxmox.com/wiki/Package_Repositories"
    echo ""
    read -p "Would you like to edit $APT_SOURCES now? [y/N]" EDIT_SOURCES
    if [[ $EDIT_SOURCES =~ ^[Yy]$ ]]; then
        nano $APT_SOURCES
    fi  
fi

# Check and see if the ceph repo is using the enterprise entry:
if grep -v "^[[:space:]]*#" "${APT_SOURCES}.d/ceph.list" | grep -q "enterprise"; then
    echo "Ceph repo contains \"enterprise\" entry:  ${APT_SOURCES}.d/ceph.list."
    read -p "Would you like to change it to \"no-subscription\"? [y/N]" EDIT_CEPH_SOURCES
    if [[ $EDIT_CEPH_SOURCES =~ ^[Yy]$ ]]; then
        result=$(sed -i.bak 's/enterprise/download/; s/enterprise/no-subscription/' "$APT_SOURCES.d/ceph.list")
        if [ $? -ne 0 ]; then
            echo "Failed to edit $APT_SOURCES.d/ceph.list: $result"
            exit 1
        fi
    fi
fi  


# check and see if the enterprise rep is enabled:
if grep -v "^[[:space:]]*#" "${APT_SOURCES}.d/pve-enterprise.list" | grep -q "pve-enterprise"; then
    echo "PVE enterprise repo is enabled in:  ${APT_SOURCES}.d/pve-enterprise.list"
    read -p "Would you like to disable it? [y/N]" EDIT_PVE_ENTERPRISE
    if [[ $EDIT_PVE_ENTERPRISE =~ ^[Yy]$ ]]; then
        result=$(sed -i.bak '/^[[:space:]]*[^#].*pve-enterprise/ s/^/#/' "${APT_SOURCES}.d/pve-enterprise.list")
        if [ $? -ne 0 ]; then
            echo "Failed to edit ${APT_SOURCES}.d/pve-enterprise.list: $result"
            exit 1
        fi
    fi
fi
