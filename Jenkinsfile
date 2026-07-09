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

        stage('Setup SSH Environment') {
            steps {
                script {
                    // Extract dynamic IP from Terraform
                    def BASTION_IP = sh(
                        script: 'terraform output -raw bastion_public_ip',
                        returnStdout: true
                    ).trim()

                    // Execute configuration in a single shell block to maintain environment
                    sh """
                        echo "Using Bastion IP: ${BASTION_IP}"
                        mkdir -p \$HOME/.ssh

                        # Validate files exist
                        if [ ! -f "\$WORKSPACE/ssh.cfg.template" ]; then
                            echo "ERROR: ssh.cfg.template not found at \$WORKSPACE"
                            exit 1
                        fi

                        # Generate config and set permissions
                        sed "s/BASTION_IP_PLACEHOLDER/${BASTION_IP}/g" \
                            \$WORKSPACE/ssh.cfg.template > \$HOME/.ssh/config
                        
                        chmod 600 \$HOME/.ssh/config
                        chmod 400 \$WORKSPACE/sandeepkey.pem

                        # Initialize agent and add key
                        eval \$(ssh-agent -s)
                        ssh-add \$WORKSPACE/sandeepkey.pem
                        ssh-add -l
                    """
                }
            }
        }

        stage('Terraform Destroy') {
            steps {
                script {
                    // Human safety gate
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
