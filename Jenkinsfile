pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION    = 'ap-south-1'
        // These IDs must match the names in your Jenkins Credentials UI
        AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
    }
    


    stages {
        stage('Checkout Code') {
            steps {
                cleanWs()
                checkout scm
                
            }
        }

        stage('Terraform Apply') {
            steps {
                // -reconfigure solves the backend conflict error
                sh 'terraform init -reconfigure'
                sh 'terraform apply -auto-approve'
            }
        }

        stage('Teardown Approvals Gate') {
            steps {
                script {
                    input message: "Infrastructure is live! Do you want to tear down?", ok: "Yes, Destroy It"
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
