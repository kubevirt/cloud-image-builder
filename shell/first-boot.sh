#! /bin/sh

######################
## This script is a one-time script used upon boot to establish a Kubevirt-enabled single 
## node "cluster" for development/testing purposes. Operations are done here (rather than 
## in kb-image-builder) if they depend on details that may vary from VM instance-to-instance.
######################

  ## Global Variables
export INVENTORY_FILE="/tmp/inventory"
export KUBEVIRT_ANSIBLE_PATH="/home/centos/kubevirt-ansible"
export KUBEVIRT_VERSION="$(cat /home/centos/kubevirt-version)"
export KUBECONFIG="/etc/kubernetes/admin.conf"
export HOME="/root"

  ## $KUBEVIRT_ANSIBLE_PATH is the default assumption
cd $KUBEVIRT_ANSIBLE_PATH

  ## Define "masters" group as consisting only of this node
cat <<EOI > $INVENTORY_FILE
[masters]
$(hostname)
EOI

  ## TODO: fix this in a PR and remove this line
sed -i '/ipalloc_range:/ s/weavenet.stdout/"{{weavenet.stdout}}"/g' /home/centos/kubevirt-ansible/playbooks/cluster/kubernetes/roles/kubernetes-master/tasks/main.yml

  ## Bootstrap a Kubernetes cluster using kubevirt-ansible
ansible-playbook -vvv playbooks/cluster/kubernetes/cluster-localhost.yml --connection=local -i $INVENTORY_FILE >/tmp/ansible-output.log 2>&1

 ## Wait for kubernetes cluster to be up
i=0
while [[ 1 ]]; do

    ## Retrieve node status for current node
  currentStatus=$(kubectl get nodes $(hostname) -o json | jq -r '.status.conditions[] | select(.reason == "KubeletReady") | .type')

    ## Break if last status read was "Ready"
  if [[ "$currentStatus" == "Ready" ]]; then

    break

  fi

  i=$(( $i + 1 ))

    ## If this is the 25th iteration then exit the script with an error.
  if [[ $i -eq 26 ]]; then
    echo "Timed Out Waiting for Kubernetes To Become Available." >&2
    exit 1
  fi

  sleep 2

done

 ## Deploy kubevirt
kubectl create namespace kubevirt

  ## If virt CPU flags aren't present, enable emulation 
  ## More info: https://github.com/kubevirt/kubevirt/blob/master/docs/software-emulation.md
grep -q -E 'vmx|svm' /proc/cpuinfo || kubectl create configmap -n kubevirt kubevirt-config --from-literal debug.useEmulation=true

kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/v${KUBEVIRT_VERSION}/kubevirt-operator.yaml 
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/v${KUBEVIRT_VERSION}/kubevirt-cr.yaml

#mv /home/centos/after-install-checks.yml .
#ansible-playbook after-install-checks.yml --connection=local -i $INVENTORY_FILE

 ## Generate The MOTD
KUBE_VERSION=$(kubectl get nodes $(hostname) -o json | jq -r .status.nodeInfo.kubeletVersion)

cat <<EOI > /etc/motd

Welcome to KubeVirt Push Button Trial

Kubernetes and KubeVirt have been pre-installed for you. You may use
the guide at http://kubevirt.io/labs/kubernetes.html to explore more.

Found a problem? Please report it to
https://github.com/kubevirt/cloud-image-builder/issues.

Versions
--------
OS:         $(cat /etc/redhat-release)
Kubernetes: $KUBE_VERSION
KubeVirt:   $KUBEVIRT_VERSION

EOI

 ## Disable and delete everything so this only runs the first time the VM boots
systemctl disable kubevirt-installer
rm -rf /home/centos/kubevirt-ansible /usr/local/bin/first-boot-centos.sh /home/centos/kubevirt-version
