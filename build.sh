#!/usr/bin/env bash
set -x
# sed -i 's@version: 0.9.5@version: 0.10.0@' kubevirt-ansible/vars/all.yml
# sed -i "s/weavenet.stdout/\"{{ weavenet.stdout }}\"/" kubevirt-ansible/roles/kubernetes-master/tasks/main.yml
# export KUBEVIRT_VERSION=$(cat kubevirt-ansible/vars/all.yml | grep version | grep -v _ver | cut -f 2 -d ' ')
# [ -f virtctl ] || curl -L -o virtctl https://github.com/kubevirt/kubevirt/releases/download/v$KUBEVIRT_VERSION/virtctl-v$KUBEVIRT_VERSION-linux-amd64
# cp ../tests/pretest-checks.yml .
# echo $KUBEVIRT_VERSION > kubevirt-version

$PACKER build -debug -machine-readable --force $PACKER_BUILD_TEMPLATE | tee build.log
echo "AWS_TEST_AMI=`egrep -m1 -oe 'ami-.{8}' build.log`" >> job.props
