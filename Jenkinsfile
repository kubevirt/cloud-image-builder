#!/usr/bin/env groovy


def containers = ['ansible-executor': [tag: 'latest', privileged: false, command: 'uid_entrypoint cat']]
def podName = "cloud-image-builder-${UUID.randomUUID().toString()}"

def archives = {
    step([$class   : 'ArtifactArchiver', allowEmptyArchive: true,
          artifacts: 'packer-build-manifest.json', fingerprint: true])
}

buildDecorator = decoratePRBuild(change_author: params['CHANGE_AUTHOR'], change_branch: params['CHANGE_BRANCH'])

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
                        credentials: params['credentials'])

            }

            stage('test-image') {
                def cmd = """
                    mkdir -p ~/.ssh
                    ansible-playbook -vvv --private-key \${SSH_KEY_LOCATION} \${PLAYBOOK}
                    """


                executeInContainer(containerName: 'ansible-executor', containerScript: cmd, stageVars: params,
                        loadProps: ['build-image'], credentials: params['credentials'])
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
                        loadProps: ['build-image'], credentials: params['credentials'])
            }
        }
    }
}
