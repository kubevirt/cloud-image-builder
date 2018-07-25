# KubeVirt Cloud Image Builder

The repo contains scripts and playbooks that can be used to build and test an Amazon AWS AMI/GCP image containing Kubernetes and KubeVirt.

## Build

Packer is used to build the KubeVirt AMIs/GCP Images, so you will need to install it first.

After you have installed packer, then take a look at the environment file corresponding to your platform. The file contains all of the enviroment variables that are expected to be filled for the build process to work. Some of these variables include your AWS key, instance type, region, security group id, path to packer, and the packer build template. Before running the build.sh script, you will need to either source this file with the appropriate values or populate them directly into your environment.

To build the Image, run the build.sh script. The script clones the kubevirt-ansible directory, copies a playbook to allow localhost installation of Kubernetes, and invokes the packer build command using the specified build template. The build template for CentOS is kubevirt-ami-centos.json.

Packer then creates an AWS instance using the base CentOS AMI. If you examine the build template, you will notice that kubevirt-ansible, a few playbooks, a first-boot.sh script, and a kubevirt-installer.service file are copied into the instance. At the very end, some packages that are used by Kubernetes and KubeVirt are preinstalled. When the provisioning steps are complete, packer shuts down the instance and creates an new AMI off of the current instance state.

Why is there a first-boot.sh script and a kubevirt-installer.service file? When you install Kubernetes, the node's hostname is incorporated in certificates and other settings, so we cannot preinstall Kubernetes in the AMI which would mean it would use the build instance's hostname. When a user creates a new instance from the AMI the hostname changes. Therefore, a service was created to execute first-boot.sh which installs Kubernetes and KubeVirt the first time the instance is started, and which will be configured with the correct hostname.

Once the build finishes, note the AMI id. We will use it in the verification step.
In the case of Gcp, you can set the image name in the environment file

## Verification

You can use the ec2-test-centos.yml playbook to verify that the AMI we built works correctly. The playbook creates an EC2 instance using a specified AMI, waits for the instance to allow SSH, and then sets up KubeVirt with a storage class, CDI, PVC, and finally starts up a cirros VM and waits for it to be in "Running" state. The storage class, CDI, PVC, and VM definitions are from https://github.com/davidvossel/hostpath-pvc-vm-disks-examples/blob/master/README.md.

To run the playbook, first examine the environment file again and fill-in values for everything under "#Ansible ec2-test". 

Then execute the playbook with your AWS private key.

```bash
ansible-playbook --private-key=<your-aws-private-key> ec2-test-centos.yml
```

You can inspect the EC2 instance and perform additional tests by logging in using

```bash
ssh -i <your-aws-private-key> centos@<ec2_instance_public_ip_or_dns_name>
```
## Pipeline
[Jenkins Pipeline](https://jenkins-kubevirt.apps.ci.centos.org/)

The pipeline consists of a multibranch pipeline job named [cloud-image-builder](https://jenkins-kubevirt.apps.ci.centos.org/job/cloud-image-builder/)
that listens for pull requests to be opened on the repository. If a pull request contains changes to an AWS related file, the [centos-aws-image-build](https://jenkins-kubevirt.apps.ci.centos.org/job/centos-aws-image-build/)
job is started. If a pull request contains changes to a GCP related file, the [centos-gcp-image-build](https://jenkins-kubevirt.apps.ci.centos.org/job/centos-gcp-image-build/)
job is started.

### cloud-image-builder
The cloud-image-builder job consists of three stages. The first stage called run-tests serves as a wrapper to
run the next two stages in parallel. The wrapped stages are centos-aws and centos-gcp. centos-aws listens for changes
to any file containing ec2, aws or ami. If it detects a change, it first sets variables related to the change author, change branch
and aws instance name. It then reads the file environment.aws and passes the variables contained in that file to the 
centos-aws-image-build job.

### centos-aws
The centos-aws job starts off by initializing a pod in Openshift with one container called ansible-executor. Then it starts 
it's first of three stages. The first stage builds an AMI using packer and then records the ami instance id.
The next stage runs tests against the image using ansible. Once the job completes successfully or in error the third stage 
is run that cleans up the AMI.

### Pipeline metrics
Basic metrics for each jenkins job can be viewed here. [Metrics](http://grafana-continuous-infra.apps.ci.centos.org/d/adsyE4Kmk/kubevirt-image-builder)

### Secrets management
Secrets are managed in OpenShift and sync to Jenkins using the [OpenShift Sync Plugin](https://github.com/openshift/jenkins-sync-plugin)
#### Examples:
```bash
# Create the secret
oc create secret generic mycert --from-file=certificate=mycert.p12 --from-literal=password=password
# Add label to mark that it should be synced.
oc label secret mysecretfile credential.sync.jenkins.openshift.io=true
```
