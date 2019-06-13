#!/usr/bin/env groovy


def gcp_credentials = [
        sshUserPrivateKey(credentialsId: 'kubevirt-gcp-ssh-private-key', keyFileVariable: 'SSH_KEY_LOCATION'),
        file(credentialsId: 'kubevirt-gcp-credentials-file', variable: 'GOOGLE_APPLICATION_CREDENTIALS'),
        file(credentialsId: 'kubevirt-gcp-ssh-public-key', variable: 'GCP_SSH_PUBLIC_KEY')

]

def aws_credentials = [
        string(credentialsId: 'kubevirt-aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
        string(credentialsId: 'kubevirt-aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY'),
        string(credentialsId: 'kubevirt-aws-subnet-id', variable: 'AWS_SUBNET_ID'),
        string(credentialsId: 'kubevirt-aws-security-group-id', variable: 'AWS_SECURITY_GROUP_ID'),
        string(credentialsId: 'kubevirt-aws-security-group', variable: 'AWS_SECURITY_GROUP'),
        string(credentialsId: 'kubevirt-aws-key-name', variable: 'AWS_KEY_NAME'),
        sshUserPrivateKey(credentialsId: 'kubevirt-aws-ssh-private-key', keyFileVariable: 'SSH_KEY_LOCATION')

]

def images = [
        'aws-centos': [
                'envFile': 'environment.aws',
                'credentials': aws_credentials
        ],
        'gcp-centos': [
                'envFile': 'environment.gcp',
                'credentials': gcp_credentials
        ]
]

builders = [:]

images.each { imageName, imageValues ->

    def podName = "${imageName}-${UUID.randomUUID().toString()}"

    builders[podName] = {

        def params = [:]
        def credentials = []

        def containers = ['ansible-executor': [tag: 'latest', privileged: false, command: 'uid_entrypoint cat']]


        def archives = {
            step([$class   : 'ArtifactArchiver', allowEmptyArchive: true,
                  artifacts: 'packer-build-*.json,ansible-*.log,published-aws-image-ids', fingerprint: true])
        }

        deployOpenShiftTemplate(containersWithProps: containers, openshift_namespace: 'kubevirt', podName: podName,
                docker_repo_url: '172.30.254.79:5000', jenkins_slave_image: 'jenkins-contra-slave:latest') {

            ciPipeline(buildPrefix: 'kubevirt-image-builder', decorateBuild: decoratePRBuild(), archiveArtifacts: archives, timeout: 120) {

                try {

                    stage("prepare-environment-${imageName}") {
                        handlePipelineStep {
                            echo "STARTING BUILD OF - ${imageName}"
                            checkout scm
                            params = readProperties file: imageValues['envFile']
                            credentials = imageValues['credentials']

                            // modify any parameters
                            imageParam = env.TAG_NAME ?: (env.BRANCH_NAME ?: 'master')
                            imageParam = "${imageParam}-build-${env.BUILD_NUMBER}".replaceAll('\\.','-')
                            params['IMAGE_NAME'] = "${params['IMAGE_NAME']}-${imageParam.toLowerCase()}"
                        }
                    }

                    stage("build-image-${imageName}") {
                        def cmd = """
                        curl -L -o /tmp/packer.zip https://releases.hashicorp.com/packer/1.2.5/packer_1.2.5_linux_amd64.zip
                        unzip /tmp/packer.zip -d .
                        sh \${BUILD_SCRIPT}
                        """

                        executeInContainer(containerName: 'ansible-executor', containerScript: cmd, stageVars: params,
                                credentials: credentials)

                    }

                    stage("test-image-${imageName}") {
                        def cmd = """
                        mkdir -p ~/.ssh
                        sh \${TEST_SCRIPT}
                        """


                        executeInContainer(containerName: 'ansible-executor', containerScript: cmd, stageVars: params,
                                loadProps: ["build-image-${imageName}"], credentials: credentials)
                    }

                    if (env['TAG_NAME']) {
                        stage("deploy-image-${imageName}") {
                            def cmd = """
                            ansible-playbook -vvv --private-key \${SSH_KEY_LOCATION} \${PLAYBOOK_DEPLOY} >ansible-${imageName}-deploy.log 2>&1
                            """

                            executeInContainer(containerName: 'ansible-executor', containerScript: cmd, stageVars: params,
                                    loadProps: ["build-image-${imageName}"], credentials: credentials)
                        }
                    }

                } catch (e) {
                    echo e.toString()
                    throw e

                } finally {
                    stage("cleanup-image-${imageName}") {
                        def cmd = """
                        sh \${CLEANUP_SCRIPT}
                        """

                        executeInContainer(containerName: 'ansible-executor', containerScript: cmd, stageVars: params,
                                loadProps: ['build-image'], credentials: credentials)
                    }

                    echo "ENDING BUILD OF - ${imageName}"
                }
            }
        }
    }
}

parallel builders
