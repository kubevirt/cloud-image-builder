#!/usr/bin/env groovy


def containers = ['ansible-executor': [tag: 'latest', privileged: false, command: 'uid_entrypoint cat']]
def podName = "cloud-image-builder-${UUID.randomUUID().toString()}"
def credentials = [
        string(credentialsId: 'kubevirt-aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
        string(credentialsId: 'kubevirt-aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY'),
        string(credentialsId: 'kubevirt-aws-subnet-id', variable: 'AWS_SUBNET_ID'),
        string(credentialsId: 'kubevirt-aws-security-group-id', variable: 'AWS_SECURITY_GROUP_ID'),
        string(credentialsId: 'kubevirt-aws-security-group', variable: 'AWS_SECURITY_GROUP'),
        string(credentialsId: 'kubevirt-aws-key-name', variable: 'AWS_KEY_NAME'),
        sshUserPrivateKey(credentialsId: 'kubevirt-aws-ssh-private-key', keyFileVariable: 'SSH_KEY_LOCATION'),
        file(credentialsId: 'kubevirt-gcp-credentials-file', variable: 'GOOGLE_APPLICATION_CREDENTIALS')
]



def archives = {
    step([$class   : 'ArtifactArchiver', allowEmptyArchive: true,
          artifacts: 'packer-build-manifest.json', fingerprint: true])
}

// decorate build with PR or TAG information
if (params['TAG_NAME'] != 'null' ) {
    buildDecorator = decoratePRBuild(tag_name: params['TAG_NAME'])

} else if (params['CHANGE_AUTHOR'] != 'null' && params['CHANGE_BRANCH'] != 'null') {
    buildDecorator = decoratePRBuild(change_author: params['CHANGE_AUTHOR'], change_branch: params['CHANGE_BRANCH'])
} else {
    buildDecorator = decoratePRBuild()
}

deployOpenShiftTemplate(containersWithProps: containers, openshift_namespace: 'kubevirt', podName: podName,
                        docker_repo_url: '172.30.254.79:5000', jenkins_slave_image: 'jenkins-contra-slave:latest') {

    ciPipeline(buildPrefix: 'kubevirt-image-builder', decorateBuild: buildDecorator, archiveArtifacts: archives) {

        try {

            stage('build-image') {
                def cmd = """
                    curl -L -o /tmp/packer.zip https://releases.hashicorp.com/packer/1.2.5/packer_1.2.5_linux_amd64.zip
                    unzip /tmp/packer.zip -d .
                    sh \${BUILD_SCRIPT}
                    """

                checkout scm
                executeInContainer(containerName: 'ansible-executor', containerScript: cmd, stageVars: params,
                        credentials: credentials)

            }

            stage('test-image') {
                def cmd = """
                    mkdir -p ~/.ssh
                    ansible-playbook -vvv --private-key \${SSH_KEY_LOCATION} \${PLAYBOOK}
                    """


                executeInContainer(containerName: 'ansible-executor', containerScript: cmd, stageVars: params,
                        loadProps: ['build-image'], credentials: credentials)
            }

            if (params['TAG_NAME']) {
                stage('deploy-image') {
                    def cmd = """
                    ansible-playbook -vvv --private-key \${SSH_KEY_LOCATION} \${PLAYBOOK_DEPLOY}
                    """

                    executeInContainer(containerName: 'ansible-executor', containerScript: cmd, stageVars: params,
                            loadProps: ['build-image'], credentials: credentials)
                }
            }

        } catch(e) {
            echo e.getMessage()
            throw e

        } finally {
            stage('cleanup-image') {
                def cmd = """
                    ansible-playbook -vvv --private-key \${SSH_KEY_LOCATION} \${PLAYBOOK_CLEANUP}
                    """
                executeInContainer(containerName: 'ansible-executor', containerScript: cmd, stageVars: params,
                        loadProps: ['build-image'], credentials: credentials)
            }
        }
    }
}

