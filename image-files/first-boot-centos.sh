#! /bin/sh
export KUBEVIRT_ANSIBLE_DIR=/home/centos/kubevirt-ansible
cd $KUBEVIRT_ANSIBLE_DIR
echo "[masters]" >> inventory-aws
hostname >> inventory-aws

sudo ansible-playbook playbooks/cluster/kubernetes/cluster-localhost.yml --connection=local -i inventory-aws

# enable kubectl for centos user
sudo cp /etc/kubernetes/admin.conf /home/centos
sudo chown centos:centos /home/centos/admin.conf
export KUBECONFIG=/home/centos/admin.conf
echo "export KUBECONFIG=~/admin.conf" >> /home/centos/.bash_profile

# wait for kubernetes cluster to be up
sudo ansible-playbook /home/centos/cluster-wait.yml --connection=local 

# deploy kubevirt
sudo ansible-playbook playbooks/kubevirt.yml -e@vars/all.yml -e cluster=kubernetes --connection=local -i inventory-aws

# generate motd
cd /home/centos
sudo ansible-playbook motd.yml -v
rm motd*

# cleanup
rm cluster-wait.yml

# disable the service so it only runs the first time the VM boots
sudo chkconfig kubevirt-installer off
