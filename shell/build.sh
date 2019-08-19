#!/bin/bash

set -x

ansible-playbook ansible/${targetEnvironment}-provision.yml > ansible-provision-${targetEnvironment}.log 2>&1
ansible-playbook --private-key ${SSH_KEY_LOCATION} -i /tmp/inventory ansible/${targetEnvironment}-setup.yml > ansible-setup-${targetEnvironment}.log 2>&1
ansible-playbook --private-key ${SSH_KEY_LOCATION} -i /tmp/inventory ansible/${targetEnvironment}-mkimage.yml > ansible-mkimage-${targetEnvironment}.log 2>&1
