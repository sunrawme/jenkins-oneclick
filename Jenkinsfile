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

        stage('Terraform Destroy - Clean Slate') {
            steps {
                // Run init to make sure the state file maps perfectly
                sh 'terraform init -reconfigure'
                // Force destroy everything
                sh 'terraform destroy -auto-approve'
            }
        }
    }
}

        stage('Terraform Apply') { steps { sh 'terraform apply -auto-approve' } }

        stage('Generate Ansible Inventory') {
            steps {
                script {
                    def activeIp = sh(script: "terraform -chdir=.. output -json sonar_node_private_ips | jq -r '.[0]'", returnStdout: true).trim()
                    def passiveIp = sh(script: "terraform -chdir=.. output -json sonar_node_private_ips | jq -r '.[1]'", returnStdout: true).trim()
                    def efsDns = sh(script: "terraform -chdir=.. output -raw efs_dns_name", returnStdout: true).trim()

                    def activeId = sh(script: "terraform -chdir=.. output -json sonar_instance_ids | jq -r '.[0]'", returnStdout: true).trim()
                    def passiveId = sh(script: "terraform -chdir=.. output -json sonar_instance_ids | jq -r '.[1]'", returnStdout: true).trim()

                    def template = readFile('ansible/inventory.ini.tpl')
                    
                    // FIXED: Escaped the dollar signs so Groovy treats them as literal strings
                    def inventoryContent = template
                        .replace('\${active_ip}', activeIp)
                        .replace('\${passive_ip}', passiveIp)
                        .replace('\${active_instance_id}', activeId)
                        .replace('\${passive_instance_id}', passiveId)
                        .replace('\${efs_dns}', efsDns)

                    writeFile(file: 'ansible/inventory.ini', text: inventoryContent)
                }
            }
        }

        stage('Ansible Playbook Execution') {
            steps {
                sleep 180 
                dir('ansible') {
                    // Run the playbook cleanly with our validated inventory mappings
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
