#!/usr/bin/env groovy


def containers = ['ansible-executor': [tag: 'latest', privileged: false, command: 'uid_entrypoint cat']]
def podName = "cloud-image-builder-${UUID.randomUUID().toString()}"
def credentials = [
        string(credentialsId: '3e509b47-7263-42dc-ac1e-99bbfaadcfe9', variable: 'AWS_ACCESS_KEY_ID'),
        string(credentialsId: '39a3fbf6-f8f9-4fc6-87bc-b294de7636ba', variable: 'AWS_SECRET_ACCESS_KEY'),
        string(credentialsId: 'b2f2d0b1-a796-4bdf-92ce-9893729fea3c', variable: 'AWS_SUBNET_ID'),
        string(credentialsId: 'befc5c54-2036-4d1d-a3d0-07be98ce8b16', variable: 'AWS_SECURITY_GROUP_ID'),
        string(credentialsId: '7177cdc3-2018-43b8-b84d-50f66f7a240a', variable: 'AWS_SECURITY_GROUP'),
        string(credentialsId: '1f549343-a22b-4d18-bc3f-87fbe30331a6', variable: 'AWS_KEY_NAME'),
        sshUserPrivateKey(credentialsId: 'ab369812-7016-40b4-8747-cb36d0e27f33', keyFileVariable: 'AWS_KEY_LOCATION')
]

def archives = {
    step([$class   : 'ArtifactArchiver', allowEmptyArchive: true,
          artifacts: 'packer-build-manifest.json', fingerprint: true])
}

deployOpenShiftTemplate(containersWithProps: containers, openshift_namespace: 'kubevirt', podName: podName,
                        docker_repo_url: '172.30.254.79:5000', jenkins_slave_image: 'jenkins-contra-slave:latest') {

    ciPipeline(buildPrefix: 'kubevirt-image-builder', decorateBuild: decoratePRBuild(), archiveArtifacts: archives) {

        stage('build-image') {
            handlePipelineStep {
                def cmd = """
                  curl -L -o /tmp/packer.zip https://releases.hashicorp.com/packer/1.2.5/packer_1.2.5_linux_amd64.zip
                  unzip /tmp/packer.zip -d .
                  sh build.sh
                  """

                checkout scm

                withCredentials(credentials) {
                    executeInContainer(containerName: 'ansible-executor', containerScript: cmd, stageVars: params)
                }
            }
        }

        stage('test-image') {
            handlePipelineStep {
                def cmd = """
                  mkdir -p ~/.ssh
                  ansible-playbook -vvv --private-key \${AWS_KEY_LOCATION} \${PLAYBOOK}
                  """

                withCredentials(credentials) {
                    executeInContainer(containerName: 'ansible-executor', containerScript: cmd, stageVars: params,
                                       loadProps: ['build-image'])

                }
            }
        }
    }
}
