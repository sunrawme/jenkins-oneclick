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
                
                // --- ADD THIS BLOCK ---
                script {
                    // Capture the IP from Terraform
                    def BASTION_IP = sh(script: "terraform output -raw bastion_public_ip", returnStdout: true).trim()
                    
                    // Replace the placeholder in your ssh.cfg file
                    // Ensure your ssh.cfg file has "BASTION_IP_HERE" as the HostName
                    sh "sed -i 's/BASTION_IP_HERE/${BASTION_IP}/g' ssh.cfg"
                }
            }
        }
        stage('Ansible Provisioning') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'sonarkey', keyFileVariable: 'SSH_KEY_PATH')]) {
                    sh '''
                        echo "Listing files to verify directory structure:"
                        ls -la
                        
                        # Now run the playbook
                        ansible-playbook -i inventory.ini playbook.yml \
                        --ssh-common-args="-F ssh.cfg -o StrictHostKeyChecking=no -o IdentityFile=${SSH_KEY_PATH}" -vvv
                    '''
                }
            }
        }
