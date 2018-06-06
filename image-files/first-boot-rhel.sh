#! /bin/sh
export KUBEVIRT_ANSIBLE_DIR=/home/ec2-user/kubevirt-ansible
cd $KUBEVIRT_ANSIBLE_DIR
echo "[masters]" >> inventory-aws
hostname >> inventory-aws

sudo ansible-playbook playbooks/cluster/kubernetes/cluster-localhost.yml --connection=local -i inventory-aws

# enable kubectl for ec2-user user
sudo cp /etc/kubernetes/admin.conf /home/ec2-user
sudo chown ec2-user:ec2-user /home/ec2-user/admin.conf
export KUBECONFIG=/home/ec2-user/admin.conf
echo "export KUBECONFIG=~/admin.conf" >> /home/ec2-user/.bash_profile

# wait for kubernetes cluster to be up
sudo ansible-playbook /home/ec2-user/cluster-wait.yml --connection=local 

# deploy kubevirt
sudo ansible-playbook playbooks/kubevirt.yml -e@vars/all.yml -e cluster=kubernetes --connection=local -i inventory-aws

# disable the service so it only runs the first time the VM boots
sudo chkconfig kubevirt-installer off
