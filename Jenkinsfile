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
                sh 'terraform init -reconfigure'
                sh 'terraform apply -auto-approve'
            }
        }
        stage('Ansible Provisioning') {
            steps {
                // This block automatically loads the key into the SSH agent for this stage
                sshagent(['sonarkey']) {
                    sh '''
                        # Ensure permissions for the key in Jenkins workspace
                        chmod 400 sandeepkey.pem
                        
                        # Run Ansible
                        ansible-playbook -i inventory.ini setup_sonarqube.yml \
                        --ssh-common-args="-F ssh.cfg -o StrictHostKeyChecking=no" -vvv
                    '''
                }
            }
        }
    }
}
