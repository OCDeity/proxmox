#!/bin/bash

echo "Updating Container Template Database..."
result=$(pveam update 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "WARNING: Failed to update container template database: $result"
fi


# Get a list of Debian templates available from the Proxmox repository:
DEBIAN_AVIALABLE=$(pveam available --section system | awk '$2 ~ /debian-./ {print $2}')



# Get a list of storage nodes that are capable of serving templates:
LOCAL_STORAGE_NODES=$(pvesm status --content vztmpl | awk 'NR>1 {print $1}')
if [ $? -ne 0 ]; then
    echo "WARNING: Failed to list storage nodes: $result"
    exit 1
fi

# We need at least one local storage node to continue:
if [ -z "$LOCAL_STORAGE_NODES" ]; then
    echo "WARNING: No suitable local storage nodes found!"
    exit 1
fi

# Iterate through the storage nodes, building an array of Debian templates:
DEBIAN_TEMPLATES=()
for name in "${LOCAL_STORAGE_NODES[@]}"; do
    volumes=$(pvesm list "$name" | awk '$1 ~ /debian/ && $3 == "vztmpl" {print $1}' | awk -F'/' '{print $NF}')
    if [ $? -eq 0 ]; then
        DEBIAN_TEMPLATES+=("${volumes[@]}")
    else
        echo "WARNING: Failed to list volumes from \"$name\" storage node!"
    fi
done

echo "Checking for latest Debian template..."

# Find the latest Debian template available locally:
LATEST_LOCAL_DEBIAN=$(echo "${DEBIAN_TEMPLATES[@]}" | sort -V | tail -n 1)
if [ -n "$LATEST_LOCAL_DEBIAN" ]; then
    echo "Local:     $LATEST_LOCAL_DEBIAN"
else
    echo "Local:     (none)"
fi

# Find the latest Debian template available from the Proxmox repository:
LATEST_AVAILABLE_DEBIAN=$(echo "${DEBIAN_AVIALABLE[@]}" | sort -V | tail -n 1)
echo "Available: $LATEST_AVAILABLE_DEBIAN"

# Compare the latest local template to the latest available template:
if [ -z "$LATEST_LOCAL_DEBIAN" ] || [ "$LATEST_LOCAL_DEBIAN" != "$LATEST_AVAILABLE_DEBIAN" ]; then

    read -p "Download the latest? [y/N]" DOWNLOAD_LATEST
    if [[ $DOWNLOAD_LATEST =~ ^[Yy]$ ]]; then
        
        if [ ${#LOCAL_STORAGE_NODES[@]} -eq 1 ]; then
            TARGET_STORAGE=${LOCAL_STORAGE_NODES[0]}
        else
            echo "Where would you like to store the template?"
            for i in "${!LOCAL_STORAGE_NODES[@]}"; do
                printf "%d) %s\n" $((i+1)) "${LOCAL_STORAGE_NODES[i]}"
            done
            
            # Prompt for selection
            read -p "Enter the number of your choice: " choice
            
            # Validate user input
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#storages[@]} ]; then
                # Convert choice to array index (arrays are 0-indexed, choices are 1-indexed)
                TARGET_STORAGE="${LOCAL_STORAGE_NODES[$((choice-1))]}"
            else
                echo "Invalid selection."
                exit 0
            fi
        fi
        
        
        echo "Downloading latest Debian template..."
        pveam download "$TARGET_STORAGE" "$LATEST_AVAILABLE_DEBIAN"
        if [ $? -ne 0 ]; then
            echo "WARNING: Failed to download latest Debian template: $result"
        fi
    fi
fi
