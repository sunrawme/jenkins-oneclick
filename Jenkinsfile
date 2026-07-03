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
                // This is your existing apply stage
                sh 'terraform init -reconfigure'
                sh 'terraform apply -auto-approve'
            }
        }

        stage('Execute Commands via Bastion') {
            steps {
                script {
                    // 1. Wait a moment for the EC2 instances to fully boot up and start SSH
                    echo "Waiting 30 seconds for instances to initialize SSH..."
                    sleep 30

                    // 2. Fetch the live private IP of the Bastion host dynamically
                    def bastionIp = sh(script: "terraform output -raw bastion_private_ip", returnStdout: true).trim()
                    
                    // 3. Discover the dynamic private IP of the running SonarQube ASG node
                    def targetIp = sh(script: "aws ec2 describe-instances --filters 'Name=tag:Name,Values=sonarqube-asg-node' 'Name=instance-state-name,Values=running' --query 'Reservations[*].Instances[*].PrivateIpAddress' --output text | head -n 1", returnStdout: true).trim()

                    if (!bastionIp || !targetIp) {
                        error "Could not retrieve dynamic IPs from AWS/Terraform."
                    }

                    echo "Connecting via Bastion (${bastionIp}) to Sonar Target Node (${targetIp})..."

                    // 4. Run the SSH script using your credential environment variables
                    withCredentials([sshUserPrivateKey(credentialsId: 'aws-ec2-private-key', keyFileVariable: 'BASTION_KEY')]) {
                        sh """
                        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${BASTION_KEY} \
                            -o ProxyCommand="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${BASTION_KEY} -W %h:%p ubuntu@${bastionIp}" \
                            ubuntu@${targetIp} "echo '=== Current Directory Structure ===' && ls -la /opt/sonarqube || echo 'Sonar directory completely missing.' && echo '=== Port Check ===' && sudo ss -tuln | grep 9000 || echo 'Nothing listening.'"
                        """
                    }
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
