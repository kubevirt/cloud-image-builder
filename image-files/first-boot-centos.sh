#! /bin/sh
export KUBEVIRT_ANSIBLE_DIR=/home/centos/kubevirt-ansible
cd $KUBEVIRT_ANSIBLE_DIR
echo "[masters]" >> inventory-aws
hostname >> inventory-aws

# make sure we use a weave network that doesnt conflict
for num in `seq 30 50` ; do
 ip r | grep -q 172.$num
 if [ "$?" != "0" ] ; then
  sed -i "s/172.30/172.$num/" playbooks/roles/kubernetes-master/vars/main.yml
  break
 fi
done

sudo ansible-playbook playbooks/cluster/kubernetes/cluster-localhost.yml --connection=local -i inventory-aws

# enable kubectl for centos user
sudo cp /etc/kubernetes/admin.conf /home/centos
sudo chown centos:centos /home/centos/admin.conf
export KUBECONFIG=/home/centos/admin.conf
echo "export KUBECONFIG=~/admin.conf" >> /home/centos/.bash_profile

# wait for kubernetes cluster to be up
sudo ansible-playbook /home/centos/cluster-wait.yml --connection=local

# deploy kubevirt
kubectl create namespace kubevirt
# enable software emulation
grep -q -E 'vmx|svm' /proc/cpuinfo || kubectl create configmap -n kubevirt kubevirt-config --from-literal debug.useEmulation=true
export KUBEVIRT_VERSION=$(cat /home/centos/kubevirt-version)
wget https://github.com/kubevirt/kubevirt/releases/download/v$KUBEVIRT_VERSION/kubevirt-operator.yaml
wget https://github.com/kubevirt/kubevirt/releases/download/v$KUBEVIRT_VERSION/kubevirt-cr.yaml
kubectl apply -f kubevirt-operator.yaml
kubectl apply -f kubevirt-cr.yaml

# validate kubevirt pods and services are up
mv /home/centos/after-install-checks.yml .
sudo ansible-playbook after-install-checks.yml --connection=local -i inventory-aws

# remove CDI because users will create it as a lab exercise
kubectl delete -f /tmp/cdi-provision.yml

# generate motd
cd /home/centos
sudo ansible-playbook motd.yml -v
rm motd*
rm kubevirt-version

# cleanup
rm cluster-wait.yml
rm emulation-configmap.yaml

# disable the service so it only runs the first time the VM boots
sudo chkconfig kubevirt-installer off
