pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'us-east-1'
        // Points to the SSH credential ID you set up in Jenkins for your AWS key pair
        SSH_CREDENTIAL_ID  = 'aws-ec2-private-key' 
    }

    stages {
        stage('Checkout Code') {
            steps {
                // Pulls the infra and configuration scripts from your repository
                checkout scm
            }
        }

        stage('Terraform Init & Validate') {
            steps {
                sh 'terraform init'
                sh 'terraform validate'
            }
        }

        stage('Terraform Apply') {
            steps {
                // Auto-approves the resource creation on AWS
                sh 'terraform apply -auto-approve'
            }
        }

        stage('Generate Ansible Inventory') {
            steps {
                script {
                    // Fetch outputs dynamically from Terraform state
                    def activeIp = sh(script: "terraform output -json sonar_node_private_ips | jq -r '.[0]'", returnStdout: true).trim()
                    def passiveIp = sh(script: "terraform output -json sonar_node_private_ips | jq -r '.[1]'", returnStdout: true).trim()
                    def efsDns = sh(script: "terraform output -raw efs_dns_name", returnStdout: true).trim()

                    // Read the Ansible inventory template
                    def template = readFile('ansible/inventory.ini.tpl')

                    // Replace placeholders with live AWS runtime values
                    def inventoryContent = template
                        .replace('${active_ip}', activeIp)
                        .replace('${passive_ip}', passiveIp)
                        .replace('${efs_dns}', efsDns)

                    // Write out the live inventory file Ansible will use
                    writeFile(file: 'ansible/inventory.ini', text: inventoryContent)
                    
                    echo "Ansible inventory successfully built for Active: ${activeIp} and Passive: ${passiveIp}"
                }
            }
        }

        stage('Ansible Playbook Execution') {
            steps {
                // Pause briefly to ensure instances are fully booted up and SSH is ready
                sleep time: 30, unit: 'SECONDS'
                
                dir('ansible') {
                    // Run the configuration playbook against your live infrastructure
                    sh 'ansible-playbook -i inventory.ini setup_sonarqube.yml'
                }
            }
        }
    }

    post {
        success {
            script {
                def albDns = sh(script: "terraform output -raw alb_dns_name", returnStdout: true).trim()
                echo "=========================================================================="
                echo " SUCCESS: Your SonarQube High Availability Cluster is ready!"
                echo " Access URL: http://${albDns}"
                echo "=========================================================================="
            }
        }
        failure {
            echo "Pipeline failed. Review logs above to debug Terraform or Ansible steps."
        }
    }
}