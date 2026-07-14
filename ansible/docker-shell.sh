#!/bin/sh
# Fix: Ansible ignores ansible.cfg on world-writable Windows/WSL bind mounts.
# setting the config file for the ansible
set -e

CFG_SRC="/workspace/ansible/ansible.cfg"
CFG_DST="/root/ansible.cfg"

if [ -f "$CFG_SRC" ]; then
  cp "$CFG_SRC" "$CFG_DST"
  chmod 600 "$CFG_DST"
  export ANSIBLE_CONFIG="$CFG_DST"
fi

export ANSIBLE_INVENTORY="/workspace/ansible/inventories/aws_ec2.yml"

exec "$@"
