#!/usr/bin/env bash
set -x

cd image-files
if [ ! -d kubevirt-ansible ]; then
  git clone https://github.com/kubevirt/kubevirt-ansible
  sed -i "s@kubectl taint nodes {{ ansible_fqdn }} node-role.kubernetes.io/master:NoSchedule- || :@kubectl taint nodes --all node-role.kubernetes.io/master-@"  kubevirt-ansible/roles/kubernetes-master/templates/deploy_kubernetes.j2

  # TODO: Remove after kubevirt-ansible has moved to 0.8.0.
  sed -i 's@version: 0.7.0@version: 0.8.0-alpha.0@' kubevirt-ansible/vars/all.yml
  # TODO: Remove after it has been added to kubevirt-ansible.
  # New parameter added with 0.8.0-alpha.0
  echo "image_pull_policy: IfNotPresent" >> kubevirt-ansible/roles/kubevirt/defaults/main.yml
fi

export KUBEVIRT_VERSION=$(cat kubevirt-ansible/vars/all.yml | grep version | grep -v _ver | cut -f 2 -d ' ')
[ -f virtctl ] || curl -L -o virtctl https://github.com/kubevirt/kubevirt/releases/download/v$KUBEVIRT_VERSION/virtctl-v$KUBEVIRT_VERSION-linux-amd64
chmod +x virtctl

cp cluster-localhost.yml kubevirt-ansible/playbooks/cluster/kubernetes
cd ..

$PACKER build -debug -machine-readable --force $PACKER_BUILD_TEMPLATE | tee build.log
echo "AWS_TEST_AMI=`egrep -m1 -oe 'ami-.{8}' build.log`" >> job.props
