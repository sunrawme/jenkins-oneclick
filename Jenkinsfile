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
                    // 1. Extract Terraform outputs cleanly
                    def bastionIp = sh(script: "terraform output -raw bastion_public_ip", returnStdout: true).trim()

                    // 2. Query AWS CLI dynamically to fetch the live Private IPs from our two isolated ASGs
                    def activeIp = sh(script: "aws ec2 describe-instances --filters 'Name=tag:aws:autoscaling:groupName,Values=sonarqube-asg-az1' 'Name=instance-state-name,Values=running' --query 'Reservations[*].Instances[*].PrivateIpAddress' --output text", returnStdout: true).trim()
                    def passiveIp = sh(script: "aws ec2 describe-instances --filters 'Name=tag:aws:autoscaling:groupName,Values=sonarqube-asg-az2' 'Name=instance-state-name,Values=running' --query 'Reservations[*].Instances[*].PrivateIpAddress' --output text", returnStdout: true).trim()

                    // Fallback to avoid empty strings if the ASG is still spawning the instance
                    if (!activeIp || !passiveIp) {
                        echo "Waiting 30 seconds for ASG instances to register IP addresses..."
                        sleep 30
                        activeIp = sh(script: "aws ec2 describe-instances --filters 'Name=tag:aws:autoscaling:groupName,Values=sonarqube-asg-az1' 'Name=instance-state-name,Values=running' --query 'Reservations[*].Instances[*].PrivateIpAddress' --output text", returnStdout: true).trim()
                        passiveIp = sh(script: "aws ec2 describe-instances --filters 'Name=tag:aws:autoscaling:groupName,Values=sonarqube-asg-az2' 'Name=instance-state-name,Values=running' --query 'Reservations[*].Instances[*].PrivateIpAddress' --output text", returnStdout: true).trim()
                    }

                    echo "Discovered Live Node IPs -> Active: ${activeIp}, Passive: ${passiveIp}"

                    // 3. Read template and map variables cleanly (EFS mapping removed)
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
                // Give the co-located database and OS processes a small moment to stabilize
                sleep 60 
                dir('ansible') {
                    withCredentials([sshUserPrivateKey(credentialsId: 'aws-ec2-private-key', keyFileVariable: 'KEY_FILE')]) {
                        // Ansible routes over the proxy jump block built into the inventory
                        sh 'ansible-playbook -i inventory.ini setup_sonarqube.yml --private-key=$KEY_FILE'
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
