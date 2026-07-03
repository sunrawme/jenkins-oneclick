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
                    echo "Fetching dynamic IPs from Terraform and AWS..."

                    def bastionIp = sh(script: "terraform output -raw bastion_private_ip", returnStdout: true).trim()
                    def targetIp = sh(script: """
                        aws ec2 describe-instances \
                            --filters "Name=instance-state-name,Values=running,pending" \
                            --query "Reservations[*].Instances[?PrivateIpAddress!='${bastionIp}'].PrivateIpAddress" \
                            --output text | head -n 1
                    """, returnStdout: true).trim()

                    echo "--- LIVE IP PATH ---"
                    echo "Bastion Host IP: ${bastionIp}"
                    echo "Target Node IP:  ${targetIp}"
                    echo "--------------------"

                    if (!bastionIp || !targetIp) {
                        error "Could not resolve network topology IPs."
                    }

                    // Securely bind the key and execute with an explicit retry loop
                    withCredentials([sshUserPrivateKey(credentialsId: 'aws-ec2-private-key', keyFileVariable: 'BASTION_KEY')]) {
                        // Using single quotes ('''') prevents Groovy interpolation warnings 
                        // and forces Jenkins to handle the key securely via shell environment variables
                        sh ''',
                            echo "Testing connectivity to Bastion host..."
                            for i in {1..6}; do
                                echo "Connection attempt $i/6..."
                                if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -i $BASTION_KEY ubuntu@''' + bastionIp + ''' exit 2>&1 | grep -q "Permission denied"; then
                                    echo "Success: Bastion SSH port is open and accepting keys!"
                                    break
                                elif [ $i -eq 6 ]; then
                                    echo "FAIL: Bastion host continuously refused connection on port 22."
                                    echo "Please check that your Bastion Security Group allows port 22 from this Jenkins agent."
                                    exit 255
                                fi
                                sleep 15
                            done

                            echo "Executing remote diagnostics on SonarQube node via Bastion..."
                            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $BASTION_KEY \
                                -o ProxyCommand="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $BASTION_KEY -W %h:%p ubuntu@''' + bastionIp + '''" \
                                ubuntu@''' + targetIp + ''' "echo '=== Current Directory Structure ===' && ls -la /opt/sonarqube || echo 'Sonar directory completely missing.' && echo '=== Port Check ===' && sudo ss -tuln | grep 9000 || echo 'Nothing listening.'"
                        '''
                    }
                }
            }
        }
        stage('Ansible Playbook Execution') {
            steps {
                script {
                    // Fetch IPs from the root directory before stepping inside the ansible folder
                    def bastionIp = sh(script: "terraform output -raw bastion_private_ip", returnStdout: true).trim()
                    def targetIp = sh(script: "aws ec2 describe-instances --filters 'Name=tag:Name,Values=sonarqube-asg-node' 'Name=instance-state-name,Values=running' --query 'Reservations[*].Instances[*].PrivateIpAddress' --output text | head -n 1", returnStdout: true).trim()

                    dir('ansible') {
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
