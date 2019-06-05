#!/usr/bin/env bash
set -x

mkdir logs
touch job.props
export KUBEVIRT_VERSION="0.16.1"

  ## TODO: Move this clone to something underneath the kubevirt org
if [ ! -d kubevirt-ansible ]; then
  git clone --single-branch -b fixes-for-cloud-image-builder https://github.com/rwsu/kubevirt-ansible

  sed -i.bak "s@kubectl taint nodes {{ ansible_fqdn }} node-role.kubernetes.io/master:NoSchedule- || :@kubectl taint nodes --all node-role.kubernetes.io/master-@"  kubevirt-ansible/roles/kubernetes-master/templates/deploy_kubernetes.j2

  #Fix for missing {{ }}
  sed -i.bak "s/weavenet.stdout/\"{{ weavenet.stdout }}\"/" kubevirt-ansible/roles/kubernetes-master/tasks/main.yml
fi

echo "Beginning Image Build Process"

  ## Used by image bootstrap service and GCP image publish
echo $KUBEVIRT_VERSION > image-files/kubevirt-version
echo $KUBEVIRT_VERSION > kubevirt-version

  ## Download virtctl if it's not already present
[ -f virtctl ] || curl -L -o image-files/virtctl https://github.com/kubevirt/kubevirt/releases/download/v${KUBEVIRT_VERSION}/virtctl-v${KUBEVIRT_VERSION}-linux-amd64
chmod +x image-files/virtctl

  ## Start the actual image build
echo "Beginning 'packer build' process..."
$PACKER_BIN build -debug -machine-readable --force $PACKER_BUILD_TEMPLATE | tee build.log
echo "AWS_TEST_AMI=`egrep -m1 -oe 'ami-.{8}' build.log`" >> job.props
