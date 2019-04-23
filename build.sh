#!/usr/bin/env bash
set -x

if [ ! -d kubevirt-ansible ]; then
  git clone --single-branch -b fixes-for-cloud-image-builder https://github.com/rwsu/kubevirt-ansible

  sed -i.bak "s@kubectl taint nodes {{ ansible_fqdn }} node-role.kubernetes.io/master:NoSchedule- || :@kubectl taint nodes --all node-role.kubernetes.io/master-@"  kubevirt-ansible/roles/kubernetes-master/templates/deploy_kubernetes.j2

  #Fix for missing {{ }}
  sed -i.bak "s/weavenet.stdout/\"{{ weavenet.stdout }}\"/" kubevirt-ansible/roles/kubernetes-master/tasks/main.yml
fi

# Update KubeVirt version here
export KUBEVIRT_VERSION=0.14.0
cd image-files
# used during first-boot to decide which version of KubeVirt to install
echo $KUBEVIRT_VERSION > kubevirt-version
[ -f virtctl ] || curl -L -o virtctl https://github.com/kubevirt/kubevirt/releases/download/v$KUBEVIRT_VERSION/virtctl-v$KUBEVIRT_VERSION-linux-amd64
chmod +x virtctl
cd ..

# for use by gcp image publish
echo $KUBEVIRT_VERSION > kubevirt-version
pwd

$PACKER build -debug -machine-readable --force $PACKER_BUILD_TEMPLATE | tee build.log
echo "AWS_TEST_AMI=`egrep -m1 -oe 'ami-.{8}' build.log`" >> job.props
