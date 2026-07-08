pipeline {
    agent any
    
    environment {
        // Ensure Terraform has access to your AWS credentials
        AWS_ACCESS_KEY_ID     = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
        AWS_DEFAULT_REGION    = 'ap-south-1' // Change to your region
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Init') {
            steps {
                sh 'terraform init'
            }
        }

        stage('Terraform Format') {
            steps {
                // Fails the build if code is not formatted
                sh 'terraform fmt -recursive'
                sh 'terraform fmt -check -diff'
            }
        }

        stage('Terraform Validate') {
            steps {
                sh 'terraform validate'
            }
        }

        stage('Terraform Plan') {
            steps {
                // Saves the plan to a file to be used later in 'apply'
                sh 'terraform plan -out=tfplan'
            }
        }
    }

    post {
        always {
            cleanWs() // Clean workspace after completion
        }
        failure {
            echo "Terraform pipeline failed. Please check the logs."
        }
    }
}
