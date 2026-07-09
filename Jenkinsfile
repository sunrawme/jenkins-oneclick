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

                sh '''
                    echo "Current workspace:"
                    pwd
                    ls -la
                '''
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

                    def BASTION_IP = sh(
                        script: 'terraform output -raw bastion_public_ip',
                        returnStdout: true
                    ).trim()

                    sh """
                        echo "Using Bastion IP: ${BASTION_IP}"

                        mkdir -p \$HOME/.ssh

                        if [ ! -f "\$WORKSPACE/ssh.cfg.template" ]; then
                            echo "ERROR: ssh.cfg.template not found"
                            echo "Files available:"
                            ls -la \$WORKSPACE
                            exit 1
                        fi

                        if [ ! -f "\$WORKSPACE/sandeepkey.pem" ]; then
                            echo "ERROR: sandeepkey.pem not found"
                            echo "Files available:"
                            ls -la \$WORKSPACE
                            exit 1
                        fi

                        sed "s/BASTION_IP_PLACEHOLDER/${BASTION_IP}/g" \
                            \$WORKSPACE/ssh.cfg.template > \$HOME/.ssh/config

                        chmod 600 \$HOME/.ssh/config

                        chmod 400 \$WORKSPACE/sandeepkey.pem

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

                    sh '''
                        terraform destroy -auto-approve
                    '''
                }
            }
        }
    }
}
