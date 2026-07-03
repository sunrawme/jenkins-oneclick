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
                    def bastionIp = sh(script: "terraform output -raw bastion_public_ip", returnStdout: true).trim()

                    withCredentials([sshUserPrivateKey(credentialsId: 'aws-ec2-private-key', keyFileVariable: 'BASTION_KEY')]) {
                        sh """#!/bin/bash
                        echo "Testing connectivity to Bastion host at ${bastionIp}..."
                        for i in {1..10}; do
                            echo "Connection attempt \${i}/10..."
                            if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -i \$BASTION_KEY ubuntu@${bastionIp} exit 2>&1 | grep -q "Permission denied"; then
                                echo "Success: Bastion SSH port is open and accepting keys!"
                                break
                            elif [ \${i} -eq 10 ]; then
                                echo "FAIL: Bastion connection dropped."
                                exit 255
                            fi
                            sleep 15
                        done
                        """
                    }
                }
            }
        }

        stage('Ansible Playbook Execution') {
            steps {
                script {
                    def bastionIp = sh(script: "terraform output -raw bastion_public_ip", returnStdout: true).trim()
                    def targetIp = sh(script: "aws ec2 describe-instances --filters 'Name=instance-state-name,Values=running,pending' --query \"Reservations[*].Instances[?PrivateIpAddress!='${bastionIp}'].PrivateIpAddress\" --output text | head -n 1", returnStdout: true).trim()

                    dir('ansible') {
                        withCredentials([sshUserPrivateKey(credentialsId: 'aws-ec2-private-key', keyFileVariable: 'KEY_FILE')]) {
                            sh "chmod 400 \$KEY_FILE"
                            sh '#!/bin/bash\n' + \
                               'ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $KEY_FILE \
                                -o ProxyCommand="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $KEY_FILE -W %h:%p ubuntu@' + bastionIp + '" \
                                ubuntu@' + targetIp + ' "echo \'=== Current Directory Structure ===\' && ls -la /opt/sonarqube || echo \'Sonar directory completely missing.\'" \
                               '
                        }
                    }
                }
            }
        }

        stage('Teardown Approvals Gate') {
            steps {
                script {
                    input message: "Infrastructure is live matching sonarqube-architecture-v3! Do you want to tear down?", ok: "Yes, Destroy It"
                }
            }
        }

        stage('Terraform Destroy') {
            steps {
                sh 'terraform destroy -auto-approve'
            }
        }
    }
}
