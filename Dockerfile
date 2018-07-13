FROM centos:latest
COPY . /usr/src/cloud-image-builder
WORKDIR /usr/src/cloud-image-builder

# NOTE: adding epel to get ansible v2.6 and ec2_instance module, v2.4 is default in Centos 7.5
RUN yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
    yum install -y ansible git go python-boto python-boto3 && \
    export GOPATH=$HOME/go && \
    export PATH=$PATH:$GOPATH/bin && \   
    go get github.com/hashicorp/packer && \
    cd $GOPATH/src/github.com/hashicorp/packer && \
    go build -o bin/packer && \
    pwd && \
    mkdir -p ~/.ssh

# TODO: replace sourcing of environment.kubevirt-ci with fetching
# secrets/values from OpenShift
CMD source /usr/src/cloud-image-builder/environment.kubevirt-ci && \
    /usr/src/cloud-image-builder/build.sh && \
    ansible-playbook --private-key kubevirt-ci-aws-sysdeseng.pem ec2-test-centos.yml ; \
    ansible-playbook ec2-test-centos-cleanup.yml
