stage('Terraform Quality Gates') {
            steps {
                script {
                    // 1. Format: Ensures code style matches Terraform standards
                    sh 'terraform fmt -check'
                    
                    // 2. Validate: Checks syntax and internal consistency
                    sh 'terraform init -backend=false' // Initialize without AWS access
                    sh 'terraform validate'
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                // 3. Plan: Preview the changes to be made
                sh 'terraform plan -out=tfplan'
            }
        }

        stage('Terraform Apply') {
            steps {
                // Apply the saved plan
                sh 'terraform apply -auto-approve tfplan'
            }
        }
