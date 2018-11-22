#!/usr/bin/env bash
set -x

if [ ! -d kubevirt-ansible ]; then
  git clone https://github.com/kubevirt/kubevirt-ansible

  sed -i "s@kubectl taint nodes {{ ansible_fqdn }} node-role.kubernetes.io/master:NoSchedule- || :@kubectl taint nodes --all node-role.kubernetes.io/master-@"  kubevirt-ansible/roles/kubernetes-master/templates/deploy_kubernetes.j2

  # set specific kubevirt version
  sed -i 's@version: 0.9.5@version: 0.10.0@' kubevirt-ansible/vars/all.yml

  #Fix for missing {{ }}
  sed -i "s/weavenet.stdout/\"{{ weavenet.stdout }}\"/" kubevirt-ansible/roles/kubernetes-master/tasks/main.yml

  # Fix for bad determination of openshift environment
  cp ./patches/kubevirt.yml kubevirt-ansible/playbooks
  cp ./patches/provision.yml kubevirt-ansible/roles/kubevirt/tasks
fi

export KUBEVIRT_VERSION=$(cat kubevirt-ansible/vars/all.yml | grep version | grep -v _ver | cut -f 2 -d ' ')
cd image-files
[ -f virtctl ] || curl -L -o virtctl https://github.com/kubevirt/kubevirt/releases/download/v$KUBEVIRT_VERSION/virtctl-v$KUBEVIRT_VERSION-linux-amd64
chmod +x virtctl

cp ../tests/pretest-checks.yml .
cd ..

echo $KUBEVIRT_VERSION > kubevirt-version
pwd

$PACKER build -debug -machine-readable --force $PACKER_BUILD_TEMPLATE | tee build.log
echo "AWS_TEST_AMI=`egrep -m1 -oe 'ami-.{8}' build.log`" >> job.props
