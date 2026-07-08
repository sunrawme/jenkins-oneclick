pipeline {
    agent any
    
    parameters {
        choice(name: 'ACTION', choices: ['plan', 'apply', 'destroy'], description: 'Choose Terraform action')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Execution') {
            steps {
                withCredentials([
                    string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    sh 'terraform init'
                    sh 'terraform fmt -recursive'
                    sh 'terraform validate'
                    
                    script {
                        if (params.ACTION == 'plan') {
                            sh 'terraform plan'
                        } else if (params.ACTION == 'apply') {
                            sh 'terraform apply -auto-approve'
                        } else if (params.ACTION == 'destroy') {
                            // Added manual gate to prevent accidental destruction
                            input message: "CAUTION: Are you sure you want to destroy all infrastructure?", ok: "Yes, Proceed"
                            sh 'terraform destroy -auto-approve'
                        }
                    }
                }
            }
        }
    }
    
    post {
        always {
            // Optional: keep workspace for state file inspection 
            // but log the final status
            echo "Pipeline finished with status: ${currentBuild.result}"
        }
    }
}
