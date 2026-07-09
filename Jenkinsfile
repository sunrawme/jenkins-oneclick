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
                    def BASTION_IP = sh(script: 'terraform output -raw bastion_public_ip', returnStdout: true).trim()

                    sh """
                        echo "Using Bastion IP: ${BASTION_IP}"
                        mkdir -p \$HOME/.ssh

                        # Locate the template file
                        TEMPLATE_FILE=""
                        if [ -f "\$WORKSPACE/ssh.cfg.template" ]; then TEMPLATE_FILE="\$WORKSPACE/ssh.cfg.template"
                        elif [ -f "\$WORKSPACE/templates/ssh.cfg.template" ]; then TEMPLATE_FILE="\$WORKSPACE/templates/ssh.cfg.template"
                        elif [ -f "\$WORKSPACE/ansible/ssh.cfg.template" ]; then TEMPLATE_FILE="\$WORKSPACE/ansible/ssh.cfg.template"
                        fi

                        if [ -z "\$TEMPLATE_FILE" ]; then
                            echo "ERROR: ssh.cfg.template not found in root, templates/, or ansible/ folders."
                            exit 1
                        fi

                        # Generate config and set permissions
                        sed "s/BASTION_IP_PLACEHOLDER/${BASTION_IP}/g" \$TEMPLATE_FILE > \$HOME/.ssh/config
                        
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
