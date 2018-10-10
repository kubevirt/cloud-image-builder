#!/usr/bin/env bash
set -x

if [ ! -d kubevirt-ansible ]; then
  git clone https://github.com/kubevirt/kubevirt-ansible
  sed -i "s@kubectl taint nodes {{ ansible_fqdn }} node-role.kubernetes.io/master:NoSchedule- || :@kubectl taint nodes --all node-role.kubernetes.io/master-@"  kubevirt-ansible/roles/kubernetes-master/templates/deploy_kubernetes.j2

  #Remove when this PR is merge: https://github.com/kubevirt/kubevirt-ansible/pull/399
  echo "  when: cli.stdout == \"oc\"" >> kubevirt-ansible/roles/cdi/tasks/provision.yml

  #TODO: remove when PR to update multus config to use weave-net instead of flannel is merged
  cp image-files/multus-config.yml kubevirt-ansible/roles/network-multus/defaults/main.yml
fi

export KUBEVIRT_VERSION=$(cat kubevirt-ansible/vars/all.yml | grep version | grep -v _ver | cut -f 2 -d ' ')
[ -f virtctl ] || curl -L -o virtctl https://github.com/kubevirt/kubevirt/releases/download/v$KUBEVIRT_VERSION/virtctl-v$KUBEVIRT_VERSION-linux-amd64
chmod +x virtctl

echo $KUBEVIRT_VERSION > kubevirt-version
pwd

$PACKER build -debug -machine-readable --force $PACKER_BUILD_TEMPLATE | tee build.log
echo "AWS_TEST_AMI=`egrep -m1 -oe 'ami-.{8}' build.log`" >> job.props
