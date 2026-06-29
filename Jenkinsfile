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
                // Wipe out the old local state cache and the local state files
                // This forces Terraform to look ONLY at your S3 bucket
                sh 'rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup'
                
                // Initialize freshly against the S3 backend without the input restrictions
                sh 'terraform init -reconfigure' 
            }
        }

        stage('Terraform Apply') { steps { sh 'terraform apply -auto-approve' } }

        stage('Generate Ansible Inventory') {
            steps {
                script {
                    def activeIp = sh(script: "terraform output -json sonar_node_private_ips | jq -r '.[0]'", returnStdout: true).trim()
                    def passiveIp = sh(script: "terraform output -json sonar_node_private_ips | jq -r '.[1]'", returnStdout: true).trim()
                    def efsDns = sh(script: "terraform output -raw efs_dns_name", returnStdout: true).trim()
                    def bastionIp = sh(script: "terraform output -raw bastion_public_ip", returnStdout: true).trim()

                    def template = readFile('ansible/inventory.ini.tpl')
                    def inventoryContent = template
                        .replace('${active_ip}', activeIp)
                        .replace('${passive_ip}', passiveIp)
                        .replace('${efs_dns}', efsDns)
                        .replace('${bastion_ip}', bastionIp)

                    writeFile(file: 'ansible/inventory.ini', text: inventoryContent)
                }
            }
        }

        stage('Ansible Playbook Execution') {
            steps {
                sleep time: 30, unit: 'SECONDS'
                dir('ansible') {
                    sh 'ansible-playbook -i inventory.ini setup_sonarqube.yml'
                }
            }
        }

        stage('Teardown Approvals Gate') {
            steps {
                script {
                    // This pauses the pipeline run window completely
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
