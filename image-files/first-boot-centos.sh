#! /bin/sh

# set variables
K8S="1.11.0"
FLANNEL="v0.10.0"
KUBEVIRT="v0.10.0"
CDI="v1.3.0"
URL="http://metadata/computeMetadata/v1/instance/attributes/"
HEADER="X-Google-Metadata-Request: True"
wget -O - $URL/k8s_version --header="$HEADER" > /tmp/x && K8S=`cat /tmp/x`
wget -O - $URL/flannel_version --header="$HEADER" > /tmp/x && FLANNEL=`cat /tmp/x`
# wget -O - $URL/kubevirt_version --header="$HEADER" > /tmp/x && KUBEVIRT=`cat /tmp/x`
wget -O - $URL/kubevirt_version --header="$HEADER" > /tmp/x 
if [ "$?" == "0" ] ; then 
KUBEVIRT=`cat /tmp/x`
else
KUBEVIRT=`curl -s https://api.github.com/repos/kubevirt/kubevirt/releases/latest| jq -r .tag_name`
fi
# wget -O - $URL/cdi_version --header="$HEADER" > /tmp/x && CDI=`cat /tmp/x`
wget -O - $URL/cdi_version --header="$HEADER" > /tmp/x
if [ "$?" == "0" ] ; then 
CDI=`cat /tmp/x`
else
CDI=`curl -s https://api.github.com/repos/kubevirt/containerized-data-importer/releases/latest| jq -r .tag_name`
fi

# make sure we use a weave network that doesnt conflict
# for num in `seq 30 50` ; do
# ip r | grep -q 172.$num
# if [ "$?" != "0" ] ; then
#  WEAVENETWORK="172.30/172.$num/24"
#  break
# fi
# done

# deploy kubernetes
echo net.bridge.bridge-nf-call-iptables=1 >> /etc/sysctl.d/99-sysctl.conf
sysctl -p
setenforce 0
sed -i "s/SELINUX=enforcing/SELINUX=permissive/" /etc/selinux/config
yum install -y docker kubelet-${K8S} kubectl-${K8S} kubeadm-${K8S}
sed -i "s/--selinux-enabled //" /etc/sysconfig/docker
systemctl enable docker && systemctl start docker
systemctl enable kubelet && systemctl start kubelet
CIDR="10.244.0.0/16"
kubeadm init --pod-network-cidr=${CIDR}
cp /etc/kubernetes/admin.conf /root/
chown root:root /root/admin.conf
export KUBECONFIG=/root/admin.conf
echo "export KUBECONFIG=/root/admin.conf" >>/root/.bashrc
kubectl taint nodes --all node-role.kubernetes.io/master-

# deploy flannel
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/${FLANNEL}/Documentation/kube-flannel.yml
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
chown root:root /root/.kube/config

# deploy dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/alternative/kubernetes-dashboard.yaml
kubectl create clusterrolebinding kubernetes-dashboard-head --clusterrole=cluster-admin --user=system:serviceaccount:kube-system:kubernetes-dashboard

# deploy kubevirt 
yum -y install xorg-x11-xauth virt-viewer wget
kubectl config set-context `kubectl config current-context` --namespace=kube-system
grep -q vmx /proc/cpuinfo || kubectl create configmap -n kube-system kubevirt-config --from-literal debug.useEmulation=true
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/${KUBEVIRT}/kubevirt.yaml
wget https://github.com/kubevirt/kubevirt/releases/download/${KUBEVIRT}/virtctl-${KUBEVIRT}-linux-amd64
mv virtctl-${KUBEVIRT}-linux-amd64 /usr/bin/virtctl
chmod u+x /usr/bin/virtctl

# deploy cdi
kubectl create ns golden
kubectl create clusterrolebinding cdi --clusterrole=edit --user=system:serviceaccount:golden:default
kubectl create clusterrolebinding cdi-apiserver --clusterrole=cluster-admin --user=system:serviceaccount:golden:cdi-apiserver
wget https://github.com/kubevirt/containerized-data-importer/releases/download/${CDI}/cdi-controller.yaml
sed -i "s/namespace:.*/namespace: golden/" cdi-controller.yaml
kubectl apply -f cdi-controller.yaml -n golden
kubectl expose svc cdi-uploadproxy -n golden

# deploy kubevirt ui
kubectl create namespace kweb-ui
kubectl create clusterrolebinding kweb-ui --clusterrole=edit --user=system:serviceaccount:kweb-ui:default
kubectl apply -f https://gist.githubusercontent.com/karmab/1ed94b351ad9728979ba1f4a6dd91e0f/raw/08d15b174a2782c365d8b52ff6323c771e0a50e8/ui.yml -n kweb-ui

# set default context
kubectl config set-context `kubectl config current-context` --namespace=default

# generate motd
# cd /home/centos
# sudo ansible-playbook motd.yml -v
# rm motd*

# disable the service so it only runs the first time the VM boots
sudo chkconfig kubevirt-installer off
