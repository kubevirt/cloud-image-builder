#!/bin/bash

set -x

  ## Download the static binaries that ansible will assume to already exist
rm -f bin/virtctl
wget https://github.com/kubevirt/kubevirt/releases/download/v${KUBEVIRT_VERSION}/virtctl-v${KUBEVIRT_VERSION}-linux-amd64 -O bin/virtctl

rm -f bin/kubectl
curl -L https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl -o bin/kubectl

  ## Execute required playbooks
ansible-playbook ansible/${targetEnvironment}-provision.yml > ansible-provision-${targetEnvironment}.log 2>&1
ansible-playbook --private-key ${SSH_KEY_LOCATION} -i /tmp/inventory ansible/${targetEnvironment}-setup.yml > ansible-setup-${targetEnvironment}.log 2>&1
ansible-playbook --private-key ${SSH_KEY_LOCATION} -i /tmp/inventory ansible/${targetEnvironment}-mkimage.yml > ansible-mkimage-${targetEnvironment}.log 2>&1
