pipeline {
    agent any
    
    parameters {
        choice(name: 'ACTION', choices: ['plan', 'apply', 'destroy'], description: 'Choose Terraform action')
    }

     stages {
        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Apply') {
            steps {
                // Delete the cached backend configuration to force a clean slate

                sh 'terraform init'
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
~

    // Note: Removed cleanWs() from 'always' because you might want 
    // to inspect the terraform.tfstate after an apply.
}
