#!/usr/bin/env bash

set -x

if [[ ! -z "$AWS_SOURCE_AMI" ]]; then
  targetEnv="ec2"
else
  targetEnv="gcp"
fi

mkdir -p ~/.ssh
ansible-playbook -vvv --private-key ${SSH_KEY_LOCATION} ${PLAYBOOK} > ansible-imagetest-${targetEnv}.log 2>&1

exit 0
