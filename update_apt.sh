#! /bin/bash

echo "Updating apt packages..."
result=$(apt update -y 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "Failed to update apt sources: $result"
    exit 1
fi

echo "Upgrading packages..."
result=$(apt upgrade -y 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "Failed to upgrade packages: $result"
    exit 1
fi
