pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION    = 'ap-south-1'
        AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
    }

    stages {
        stage('Checkout') {
            steps {
                cleanWs()
                checkout scm
            }
        }

        stage('Terraform Init') {
            steps {
                sh 'terraform init -reconfigure'
            }
        }

        stage('Terraform Format') {
            steps {
                sh 'terraform fmt -recursive'
            }
        }

        stage('Terraform Validate') {
            steps {
                sh 'terraform validate'
            }
        }

        stage('Terraform Plan') {
            steps {
                sh 'terraform plan'
            }
        }

        stage('Terraform Apply') {
            steps {
                sh 'terraform init -reconfigure && terraform apply -auto-approve'
            }
        }

        stage('Setup SSH Environment') {
            steps {
                script {
                    def BASTION_IP = sh(script: 'terraform output -raw bastion_public_ip', returnStdout: true).trim()

                    def sshConfig = """
Host bastion
  HostName ${BASTION_IP}
  User ubuntu
  IdentityFile ${WORKSPACE}/sandeepkey.pem

Host 10.0.*
  ProxyJump bastion
  User ubuntu
  IdentityFile ${WORKSPACE}/sandeepkey.pem
"""

                    writeFile file: "${env.HOME}/.ssh/config", text: sshConfig

                    sh """
                        chmod 600 ${env.HOME}/.ssh/config
                        chmod 400 ${WORKSPACE}/sandeepkey.pem

                        # Initialize agent
                        eval \$(ssh-agent -s)
                        ssh-add ${WORKSPACE}/sandeepkey.pem
                        ssh-add -l
                    """
                }
            }
        }

        stage('Terraform Destroy') {
            steps {
                script {
                    input(message: 'Are you sure you want to destroy the infrastructure?', ok: 'Yes, Destroy')
                    sh 'terraform destroy -auto-approve'
                }
            }
        }
    }
}
