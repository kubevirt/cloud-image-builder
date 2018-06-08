cd image-files
git clone https://github.com/kubevirt/kubevirt-ansible/

export KUBEVIRT_VERSION=$(cat kubevirt-ansible/vars/all.yml | grep version | grep -v _ver | cut -f 2 -d ' ')
curl -L -o virtctl https://github.com/kubevirt/kubevirt/releases/download/v$KUBEVIRT_VERSION/virtctl-v$KUBEVIRT_VERSION-linux-amd64
chmod +x virtctl

cp cluster-localhost.yml kubevirt-ansible/playbooks/cluster/kubernetes
cd ..

$PACKER build $PACKER_BUILD_TEMPLATE
