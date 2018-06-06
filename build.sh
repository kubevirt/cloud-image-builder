cd image-files
git clone https://github.com/kubevirt/kubevirt-ansible/
cp cluster-localhost.yml kubevirt-ansible/playbooks/cluster/kubernetes
cd ..
$PACKER build $PACKER_BUILD_TEMPLATE
