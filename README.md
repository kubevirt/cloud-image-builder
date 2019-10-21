# Cloud Image Builder

This repository will contain the Image generation for AWS, GCP and also for Minikube.

## Resources

- Jenkins jobs:
    - Image Generation: https://jenkins-kubevirt.apps.ci.centos.org/job/dev/job/jodavis/job/kvio-lab-images/

## Workflow

The workflow starts on a Jenkins pipeline which fill some env vars and then executes the jobs:

- `shell/build.sh`

This script will execute 3 ansible playbooks:

- `${PROVIDER}-provision.yml`: Creates the instance on ${PROVIDER} and waits for SSH access (CentOS7)
- `${PROVIDER}-setup.yml`: Download/Copy the needed resources, installs a script called `first-boot.sh` which will install K8s and then Kubevirt on it when the user create an instance of that image (not on the image generation).
- `${PROVIDER}-mkimage.yml`: Stops the instance, Create a ${PROVIDER} Image from the stopped instance, Deletes the source instance and then creates a new instance of googlecloud-sdk prepared to upload the image to a GCS bucket (but not yet).

Then the next step comes in:

- `shell/publish.sh`

This process will execute 1 another ansible playbook:

- `${PROVIDER}-publish.yml`: On the previous instace created using a googlecloud-sdk base image:
    - Copy the credentials to remote instance.
    - Exports the image generated to a GCS bucket on a tar.gz file
    - Stops and delete the instance.
    - The exported Targz file contains the raw disk of the GCE instance.

On AWS case, this last step changes. The YAML file will propagate the AMI image among some regions (listed bellow), then a JSON file is generated with the AMI ID's info.

### AWS Regions to propagate to

- us-east-1
- us-east-2
- us-west-2
- ca-central-1
- eu-west-1
- eu-west-2
- eu-west-3
- eu-central-1
- ap-northeast-1
- ap-southeast-1
- ap-southeast-2
- ap-south-1
- sa-east-1

## Enhancements

This repo let the user to access to an instance on GCE or AWS which contains all the necessary to run through the labs, but does not install anything until the user spin up the instance. This is important to know because we only gain some speed downloading some resources and we need to maintain many things and dedicate some resources to do this.

### TO-DO

- Inline inventories.
- ENV Vars for Ansible config.
- Make ${PROVIDER}-setup.yml generic for all providers using `block`.
- Maybe we could valorate to create generic YAML files instead of have one per provider.
- Use [Krew](https://github.com/kubernetes-sigs/krew) to install `virtctl` as a plugin
- Reduce Ansible `copy` tasks using loops.
- Delete bin folder in order to download from internet.
- Deploy Kubevirt and CDI using operator instead of kubevirt-ansible.
