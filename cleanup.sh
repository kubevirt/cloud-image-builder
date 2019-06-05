#!/usr/bin/env bash

set -x

ansible-playbook -vvv --private-key ${SSH_KEY_LOCATION} ${PLAYBOOK_CLEANUP}

exit 0
