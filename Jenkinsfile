pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION    = 'ap-south-1'
        AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
    }

    stages {

        stage('Checkout') {
            steps {
                cleanWs()
                checkout scm
            }
        }

        stage('Terraform Apply') {
            steps {
                sh '''
                    terraform init -reconfigure
                    terraform apply -auto-approve
                '''
            }
        }

        stage('Start SSH Agent') {
            steps {
                sh '''
                    chmod 400 sandeepkey.pem

                    eval "$(ssh-agent -s)"

                    ssh-add sandeepkey.pem

                    ssh-add -l
                '''
            }
        }

        stage('Terraform Destroy') {
            steps {
                script {
                    input(
                        message: 'Are you sure you want to destroy the infrastructure?',
                        ok: 'Yes, Destroy'
                    )

                    sh 'terraform destroy -auto-approve'
                }
            }
        }

    }
}
