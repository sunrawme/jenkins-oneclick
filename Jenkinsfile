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

        stage('Execute Commands via Bastion') {
            steps {
                script {
                    echo "Waiting 30 seconds for instances to initialize SSH..."
                    sleep 30

                    // Fetch live IPs from Terraform & AWS CLI
                    def bastionIp = sh(script: "terraform output -raw bastion_private_ip", returnStdout: true).trim()
                    def targetIp = sh(script: "aws ec2 describe-instances --filters 'Name=tag:Name,Values=sonarqube-asg-node' 'Name=instance-state-name,Values=running' --query 'Reservations[*].Instances[*].PrivateIpAddress' --output text | head -n 1", returnStdout: true).trim()

                    if (!bastionIp || !targetIp) {
                        error "Could not retrieve dynamic IPs from AWS/Terraform."
                    }

                    echo "Connecting via Bastion (${bastionIp}) to Sonar Target Node (${targetIp})..."

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
                script {
                    dir('ansible') {
                        // Fetch the same live dynamic IPs for this stage as well
                        def bastionIp = sh(script: "terraform output -raw bastion_private_ip", returnStdout: true).trim()
                        def targetIp = sh(script: "aws ec2 describe-instances --filters 'Name=tag:Name,Values=sonarqube-asg-node' 'Name=instance-state-name,Values=running' --query 'Reservations[*].Instances[*].PrivateIpAddress' --output text | head -n 1", returnStdout: true).trim()

                        withCredentials([sshUserPrivateKey(credentialsId: 'aws-ec2-private-key', keyFileVariable: 'KEY_FILE')]) {
                            sh "chmod 400 \$KEY_FILE"
                            
                            echo "=== TRACING ASG INSTANCE ${targetIp} VIA BASTION JUMP ${bastionIp} ==="
                            
                            sh """
                            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i \${KEY_FILE} \
                                -o ProxyCommand="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i \${KEY_FILE} -W %h:%p ubuntu@${bastionIp}" \
                                ubuntu@${targetIp} "echo '=== Current Directory Structure ===' && ls -la /opt/sonarqube || echo 'Sonar directory completely missing.' && echo '=== Port Check ===' && sudo ss -tuln | grep 9000 || echo 'Nothing listening.'"
                            """
                        }
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
