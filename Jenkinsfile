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
                sh '''
                    terraform init -reconfigure
                    terraform apply -auto-approve
                '''
            }
        }

        stage('Configure SSH') {
            steps {
                script {
                    def BASTION_IP = sh(
                        script: 'terraform output -raw bastion_public_ip',
                        returnStdout: true
                    ).trim()

                    sh """
                        mkdir -p ~/.ssh

                        sed 's/BASTION_IP_PLACEHOLDER/${BASTION_IP}/g' \
                            ssh.cfg.template > ~/.ssh/config

                        chmod 600 ~/.ssh/config
                        chmod 400 sandeepkey.pem

                        # Start SSH agent
                        eval \$(ssh-agent -s)

                        # Add private key
                        ssh-add sandeepkey.pem

                        # Verify key is loaded
                        ssh-add -l

                        # Example commands that use SSH
                        # ssh -o StrictHostKeyChecking=no bastion "hostname"
                        # ansible-playbook -i inventory playbook.yml
                    """
                }
            }
        }

        stage('Terraform Destroy') {
            steps {
                script {
                    input(
                        message: 'Are you sure you want to destroy the infrastructure?',
                        ok: 'Yes, Destroy'
                    )

                    sh 'terraform destroy -auto-approve'
                }
            }
        }
    }
}
