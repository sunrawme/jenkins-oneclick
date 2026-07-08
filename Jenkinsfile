pipeline {
    agent any
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        stage('Terraform') {
            steps {
                withCredentials([
                    string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    sh 'terraform init'
                    sh 'terraform fmt -recursive'
                    sh 'terraform validate'
                    sh 'terraform plan -out=tfplan'
                }
            }
        }
    }

    post {
        always {
            // Note: This will delete tfplan. 
            // If you need it for a later stage, comment this out.
            cleanWs() 
        }
        failure {
            echo "Terraform pipeline failed. Please check the logs."
        }
    }
}
