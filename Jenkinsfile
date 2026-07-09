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
                
                script {
                    def BASTION_IP = sh(script: "terraform output -raw bastion_public_ip", returnStdout: true).trim()
                    sh "sed -i 's/BASTION_IP_HERE/${BASTION_IP}/g' ssh.cfg"
                }
            }
        }
        stage('Ansible Provisioning') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'sonarkey', keyFileVariable: 'SSH_KEY_PATH')]) {
                    sh '''
                        echo "Generating inventory file..."
                        # Fetch the private IPs from Terraform outputs
                        ACTIVE_IP=$(terraform output -raw sonar_active_private_ip)
                        PASSIVE_IP=$(terraform output -raw sonar_passive_private_ip)
                        
                        # Create the inventory file
                        echo "[sonarqube_nodes]" > inventory.ini
                        echo "$ACTIVE_IP" >> inventory.ini
                        echo "$PASSIVE_IP" >> inventory.ini
                        
                        echo "Inventory generated:"
                        cat inventory.ini
                        
                        # Now run the playbook
                        ansible-playbook -i inventory.ini playbook.yml \
                        --ssh-common-args="-F ssh.cfg -o StrictHostKeyChecking=no -o IdentityFile=${SSH_KEY_PATH}" -vvv
                    '''
                }
            }
        }
