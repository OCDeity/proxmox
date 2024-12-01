#!/bin/bash

# Regenerate our SSH keys
rm -f /etc/ssh/ssh_host_*
ssh-keygen -A
