pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION    = 'ap-south-1'
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
                sh 'terraform init -reconfigure -migrate-state'
                sh 'terraform apply -auto-approve'
            }
        }

        stage('Teardown Approvals Gate') {
            steps {
                script {
                    input message: "Infrastructure is live matching your custom AMIs! Do you want to tear down?", ok: "Yes, Destroy It"
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
