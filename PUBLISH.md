
Those are some additional notes regarding the overall project and publishing process, to serve as a quick reference

# General Guidelines

- kubernetes is installed with kubevirt-ansible
- kubvevirt is deployed using the operator and the cr manifest
- request account for kubevirt jenkins instance on https://jenkins-kubevirt.apps.ci.centos.org. Contact bstinson or file ticket at https://bugs.centos.org/)

# Process for publishing a new version

- submit PR to change KUBEVIRT_VERSION (and merge it)
- run manually an instance test in gcp or aws to see everything works
- create a new branch release-0.14 in the repo
- create a new release v0.14.0-1 against the newly created branch
- go to [jenkins](https://jenkins-kubevirt.apps.ci.centos.org/blue/organizations/jenkins/cloud-image-builder/detail)
- the jenkins job builds the images only when the release gets created ( at the bottom)
- the build needs to be launched with the run button
- it takes up to an hour to finish
- once it s finished, in the build log, we want to look at the published-aws-image-ids to get the new ids and and we want to update the kubevirt.github.io with the correct ami ids in the ec2.md (US WEST-1-A)
- finally we want to remove all the old ami. For this, there is a playbook called ec_ami_cleanup which uses the aws_ami_name variable
- for the US WEST-1-A region, we keep the old image but we need to make it private so it s not public
