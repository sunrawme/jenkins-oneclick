pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION    = 'us-east-1'
        AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
    }

    stages {
        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Apply') { 
            steps { 
                sh 'terraform init -reconfigure'
                sh 'terraform apply -auto-approve' 
            } 
        }

        stage('Generate Ansible Inventory') {
            steps {
                script {
                    def bastionIp = sh(script: "terraform output -raw bastion_public_ip", returnStdout: true).trim()
                    echo "Discovered Bastion IP: ${bastionIp}"

                    // --- NEW FIX: Wait up to 2 minutes for Bastion SSH to wake up ---
                    echo "Checking if Bastion SSH is ready..."
                    def sshReady = false
                    for (int i = 0; i < 6; i++) {
                        def exitCode = sh(script: "nc -z -w 5 ${bastionIp} 22", returnStatus: true)
                        if (exitCode == 0) {
                            echo "Bastion SSH is up and listening!"
                            sshReady = true
                            break
                        }
                        echo "Bastion SSH not ready yet (port 22 refused). Waiting 20 seconds..."
                        sleep 20
                    }

                    if (!sshReady) {
                        error "Bastion Host failed to start SSH on port 22 within 2 minutes."
                    }

                    // Query live private node IPs
                    def activeIp = sh(script: "aws ec2 describe-instances --filters 'Name=tag:aws:autoscaling:groupName,Values=sonarqube-asg-az1' 'Name=instance-state-name,Values=running' --query 'Reservations[*].Instances[*].PrivateIpAddress' --output text", returnStdout: true).trim()
                    def passiveIp = sh(script: "aws ec2 describe-instances --filters 'Name=tag:aws:autoscaling:groupName,Values=sonarqube-asg-az2' 'Name=instance-state-name,Values=running' --query 'Reservations[*].Instances[*].PrivateIpAddress' --output text", returnStdout: true).trim()

                    echo "Discovered Live Node IPs -> Active: ${activeIp}, Passive: ${passiveIp}"

                    def template = readFile('ansible/inventory.ini.tpl')
                    def inventoryContent = template
                        .replace('\${bastion_ip}', bastionIp)
                        .replace('\${active_ip}', activeIp)
                        .replace('\${passive_ip}', passiveIp)

                    writeFile(file: 'ansible/inventory.ini', text: inventoryContent)
                }
            }
        }
        stage('Ansible Playbook Execution') {
            steps {
                sleep 10 
                dir('ansible') {
                    withCredentials([sshUserPrivateKey(credentialsId: 'aws-ec2-private-key', keyFileVariable: 'KEY_FILE')]) {
                        sh "chmod 400 \$KEY_FILE"
                        
                        echo "=== TRACING INSTANCE 10.0.3.242 VIA BASTION JUMP ==="
                        // This uses your temporary Jenkins key to reach right into the private layer
                        sh 'ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $KEY_FILE -o ProxyCommand="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $KEY_FILE -W %h:%p ubuntu@10.0.1.234" ubuntu@10.0.3.242 "echo \\"=== Current Directory Structure ===\\" && ls -la /opt/sonarqube || echo \\"Sonar directory completely missing.\\" && echo \\"=== Port Check ===\\" && sudo ss -tuln | grep 9000 || echo \\"Nothing listening.\\""'
                    }
                }
            }
        }

        stage('Teardown Approvals Gate') {
            steps {
                script {
                    input message: "Infrastructure is live matching sonarqube-architecture-v3! Do you want to tear down and DESTROY it?", ok: "Yes, Destroy It"
                }
            }
        }

        stage('Terraform Destroy') {
            steps {
                echo "Cleaning up architecture infrastructure..."
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
