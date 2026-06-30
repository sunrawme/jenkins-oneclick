pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION    = 'us-east-1'
        SSH_CREDENTIAL_ID     = 'aws-ec2-private-key' 
        AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
    }

    stages {
        stage('Checkout Code') { steps { checkout scm } }

        stage('Terraform Init') {
            steps {
                sh 'rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup'
                sh 'terraform init -reconfigure' 
            }
        }

        stage('Terraform Apply') { steps { sh 'terraform apply -auto-approve' } }

        stage('Generate Ansible Inventory') {
            steps {
                script {
                    // 1. Fetch IP and configuration mappings from Terraform
                    def activeIp = sh(script: "terraform output -json sonar_node_private_ips | jq -r '.[0]'", returnStdout: true).trim()
                    def passiveIp = sh(script: "terraform output -json sonar_node_private_ips | jq -r '.[1]'", returnStdout: true).trim()
                    def efsDns = sh(script: "terraform output -raw efs_dns_name", returnStdout: true).trim()

                    def activeId = sh(script: "terraform output -json sonar_instance_ids | jq -r '.[0]'", returnStdout: true).trim()
                    def passiveId = sh(script: "terraform output -json sonar_instance_ids | jq -r '.[1]'", returnStdout: true).trim()

                    // 2. Build out the inventory text file
                    def template = readFile('ansible/inventory.ini.tpl')
                    def inventoryContent = template
                        .replace('${active_ip}', activeIp)
                        .replace('${passive_ip}', passiveIp)
                        .replace('${active_instance_id}', activeId)
                        .replace('${passive_instance_id}', passiveId)
                        .replace('${efs_dns}', efsDns)

                    writeFile(file: 'ansible/inventory.ini', text: inventoryContent)

                    // 3. AUTOMATED FIX: Generate a localized .aws config right here in the workspace
                    sh 'mkdir -p ansible/.aws'
                    
                    def credsContent = """[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
"""
                    def configContent = """[default]
region = us-east-1
output = json
"""
                    writeFile(file: 'ansible/.aws/credentials', text: credsContent)
                    writeFile(file: 'ansible/.aws/config', text: configContent)
                }
            }
        }

        stage('Ansible Playbook Execution') {
            steps {
                sleep 180 // Wait for the new EC2 nodes to spin up
                dir('ansible') {
                    withCredentials([sshUserPrivateKey(credentialsId: 'aws-ec2-private-key', keyFileVariable: 'KEY_FILE')]) {
                        sh 'ansible-playbook -i inventory.ini setup_sonarqube.yml --private-key=$KEY_FILE'
                    }
                }
            }
        }

        stage('Teardown Approvals Gate') {
            steps {
                script {
                    input message: "Infrastructure is live! Do you want to tear down and DESTROY the infrastructure now?", ok: "Yes, Destroy It"
                }
            }
        }

        stage('Terraform Destroy') {
            steps {
                echo "Cleaning up infrastructure..."
                sh 'terraform destroy -auto-approve'
            }
        }
    }

    post {
        success {
            echo "Pipeline run completed successfully."
        }
    }
}
