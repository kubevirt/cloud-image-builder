# KubeVirt Cloud Image Builder

The repo contains scripts and playbooks that can be used to build and
test an Amazon AWS AMI/GCP image containing Kubernetes and KubeVirt.

## Links

* CI Status: https://jenkins-kubevirt.apps.ci.centos.org/blue/organizations/jenkins/cloud-image-builder/activity

## Process Overview

Jenkins initiates an image build and test for each PR submitted or tag
that is created in this repo. A container is created to encapsulate the
entire process. A repo administrator creates tags to mark a new release
of cloud images that usually correspond to a new version of KubeVirt.
Images are published for public consumption only by way of tags. The
publish step does not run for PRs.

1. The first step is image build. Images are built using Packer. The
container downloads and installs Packer and then executes build.sh which
is a wrapper around the packer command to build an image for a particular
cloud provider. Builds are initiated for both AWS and GCP. The credentials
required to communicate with each cloud provider are stored as secrets
in OpenShift.

2. If the build is successful, the image undergoes verification. An
instance is brought up for each cloud provider, and a corresponding
test playbook is executed (ec2-test-centos.yml for AWS and gcp-test-centos.yml
for GCP). The tests creates a storage class, the CDI provisioner, a PVC,
and a VM containing cirros and verifies that the cirros VM reaches a
running state.

CI marks the PR as verified if the test is successful on all cloud
providers. It also executes playbooks to cleanup the test environment
terminating the cloud instances that were brought up.

3. If the build is initiated by way of a new tag, then it executes the
publishing step through two playbooks: aws-image-publish.yml and
gcp-image-publish.yml.

a. Making AWS image publicly available

The original image that was built and tested was created in the us-east-1
region. The aws-image-publish.yml playbook makes this image as public
and then copies the image to all other AWS regions and makes them public.

b. Making GCP image publicly available

The following command is used to make the constructed image publicly available

```
PROJECT="cnvlab-209908"
BUCKET="kubevirt-button"
IMAGE="kubevirt-button"
VERSION="v0.7.0"
gcloud compute images export --destination-uri gs://$BUCKET/$VERSION.tar.gz --image $IMAGE --project $PROJECT
```
## Releases

Cloud-image-builder releases mirror KubeVirt releases. When a new version
of Kubevirt is released, we create a new PR to edit build.sh to update the
version of Kubevirt that is install in the images. Once that PR is merged,
we can proceed to branch and tag a new release.

We create a new release branch with the name "release-<version number>"
matching the KubeVirt release branch name, e.g. "release-0.8". Then we
also create a new version tag based off the new release branch with the
version number as its name, e.g. "v0.8.0-1".

Tagging also creates a new branch in Jenkins. The CI build does not start
automatically for the new branch in Jenkins. An admin must initiate the
build for the branch here: https://jenkins-kubevirt.apps.ci.centos.org/blue/organizations/jenkins/cloud-image-builder/branches
Start the build matching the version tag name. Monitor the release build
and see that it passes. When it is complete you should be able to see
a new public AMI in all AWS regions and a new file in the "kubevirt-button"
GCP bucket.

Finally, the [EC2 page](https://github.com/kubevirt/kubevirt.github.io/blob/master/pages/ec2.md) on [kubevirt.io](http://kubevirt.io) will need to be updated
so that it points to the new AMIs. Old AMIs should also be deleted. The
ec2-ami-cleanup.yml playbook can be used to delete old AMIs in all regions
except us-west-1. The old us-west-1 AMI's visibility should be switched to
private. We keep copies of old AMIs in us-west-1 in the event we need to rollback.

## Pipeline
[Jenkins Pipeline](https://jenkins-kubevirt.apps.ci.centos.org/)

The pipeline consists of a multibranch pipeline job named [cloud-image-builder](https://jenkins-kubevirt.apps.ci.centos.org/job/cloud-image-builder/)
that listens for pull requests to be opened on the repository. When a pull request is opened a pipeline job is created and initiated.
Also, when a commit is pushed to an open pull request, the corresponding pipeline job runs. The pipeline job runs a build
for each configured image in parallel. Currently it builds a CentOS image for GCP and AWS.

### cloud-image-builder
The cloud-image-builder job consists of four stages. The first stage
called prepare-environment loads all variables related to each image. The next stage, build-image invokes packer to build the
respective image for the environment. After that the test-image stage is called. This stage runs an ansible playbook that contains
tests for each image. The final stage is deploy-image. This stage runs an ansible playbook to publish the image. This stage only
runs if a tag was pushed to the repository.

### Jenkins jobs
There is a Jenkins job for the master branch, a job for each PR and git tag.
#### master branch job
This job runs on each merge to master.
#### PR jobs
This job runs on each opened PR and each commit to the PR. The job checks out the PR and merges it with the master branch
and then runs through each testing phase.
#### Tag jobs
This job is created when a new tag is pushed to the repository. The job will only run when manually invoked.

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

## Execute Image Builds Manually

Packer is used to build the KubeVirt AMIs/GCP Images, so you will need
to install it first.

After you have installed Packer, then take a look at the environment
file corresponding to your platform. The file contains all of the
enviroment variables that are expected to be filled for the build
process to work. Some of these variables include your AWS key, instance
type, region, security group id, path to packer, and the packer build
template. Before running the build.sh script, you will need to either
source this file with the appropriate values or populate them directly
into your environment.

To build the Image, run the build.sh script. The script clones the
kubevirt-ansible directory, copies a playbook to allow localhost
installation of Kubernetes, and invokes the packer build command using
the specified build template. The build template for CentOS is
kubevirt-ami-centos.json.

Packer then creates an AWS instance using the base CentOS AMI. If you
examine the build template, you will notice that kubevirt-ansible, a
few playbooks, a first-boot.sh script, and a kubevirt-installer.service
file are copied into the instance. At the very end, some packages that
are used by Kubernetes and KubeVirt are preinstalled. When the
provisioning steps are complete, packer shuts down the instance and
creates an new AMI off of the current instance state.

Why is there a first-boot.sh script and a kubevirt-installer.service
file? When you install Kubernetes, the node's hostname is incorporated
in certificates and other settings, so we cannot preinstall Kubernetes
in the AMI which would mean it would use the build instance's hostname.
When a user creates a new instance from the AMI the hostname changes.
Therefore, a service was created to execute first-boot.sh which installs
Kubernetes and KubeVirt the first time the instance is started, and which
will be configured with the correct hostname.

Once the build finishes, note the AMI id. We will use it in the verification step.
In the case of GCP, you can set the image name in the environment file

## Execute Test Manually

You can use the ec2-test-centos.yml playbook to verify that the AMI we
built works correctly. The playbook creates an EC2 instance using a
specified AMI, waits for the instance to allow SSH, and then sets up
KubeVirt with a storage class, CDI, PVC, and finally starts up a cirros
VM and waits for it to be in "Running" state. The storage class, CDI,
PVC, and VM definitions are from https://github.com/davidvossel/hostpath-pvc-vm-disks-examples/blob/master/README.md.

To run the playbook, first examine the environment file again and fill-in
values for everything under "#Ansible ec2-test".

Then execute the playbook with your AWS private key.

```bash
ansible-playbook --private-key=<your-aws-private-key> ec2-test-centos.yml
```

You can inspect the EC2 instance and perform additional tests by logging
in using

```bash
ssh -i <your-aws-private-key> centos@<ec2_instance_public_ip_or_dns_name>
```

# Creating the AWS Source AMI

We use the Packer amazon-ebs builder to create the AWS images. This builder
takes a source AMI and launches an EC2 instance. The builder is then
configured to augment the image through shell commands to run yum install
for example or by directly copying files onto the EC2 instance. After
the build is complete, the instance is shutdown and an AMI is created
from it.

We use the latest CentOS marketplace AMI as the source AMI for our AWS
images. A consequence of using the marketplace AMI is that it doesn't allow
you to make derivative AMIs publicly available as there is a product
code tied to it and there isn't a way to remove the product code through
Packer.

The aws-build-base-ami.yml playbook can be used to make a copy of the
marketplace AMI stripping out the product code.

````bash
# modify and then source environment.aws
ansible-playbook --private-key=<your-aws-private-key> aws-build-base-ami.yml
````

After the base AWS AMI is built, update AWS_SOURCE_AMI with the newly built
AMI id and submit a new PR.

A new source AMI may need to be built when a new CentOS release and
marketplace AMI is made available.
