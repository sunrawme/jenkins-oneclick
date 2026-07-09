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
                # Install the Amazon AWS collection if it's missing
                ansible-galaxy collection install amazon.aws
                
                # Run the playbook using the dynamic inventory file
                ansible-playbook -i aws_ec2.yml playbook.yml \
                --ssh-common-args="-F ssh.cfg -o StrictHostKeyChecking=no -o IdentityFile=${SSH_KEY_PATH}" -vvv
            '''
        }
    }
}
