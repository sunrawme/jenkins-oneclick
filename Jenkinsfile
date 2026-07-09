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
        stage('Terraform Apply') {
            steps {
                sh 'terraform init -reconfigure && terraform apply -auto-approve'
            }
        }
        stage('Setup SSH Environment') {
            steps {
                script {
                    def BASTION_IP = sh(script: "terraform output -raw bastion_public_ip", returnStdout: true).trim()
                    
                    // Bundle everything that needs the SSH agent into ONE shell block
                    sh """
                        mkdir -p ~/.ssh
                        sed 's/BASTION_IP_PLACEHOLDER/${BASTION_IP}/g' ssh.cfg.template > ~/.ssh/config
                        chmod 600 ~/.ssh/config
                        
                        chmod 400 sandeepkey.pem
                        
                        # Start agent AND add key in the same block
                        eval \$(ssh-agent -s)
                        ssh-add sandeepkey.pem
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
