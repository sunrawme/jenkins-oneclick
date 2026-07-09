stage('Setup SSH Environment') {
            steps {
                script {
                    def BASTION_IP = sh(script: 'terraform output -raw bastion_public_ip', returnStdout: true).trim()

                    sh """
                        echo "Using Bastion IP: ${BASTION_IP}"
                        mkdir -p \$HOME/.ssh

                        # Locate the template file
                        TEMPLATE_FILE=""
                        if [ -f "\$WORKSPACE/ssh.cfg.template" ]; then TEMPLATE_FILE="\$WORKSPACE/ssh.cfg.template"
                        elif [ -f "\$WORKSPACE/templates/ssh.cfg.template" ]; then TEMPLATE_FILE="\$WORKSPACE/templates/ssh.cfg.template"
                        elif [ -f "\$WORKSPACE/ansible/ssh.cfg.template" ]; then TEMPLATE_FILE="\$WORKSPACE/ansible/ssh.cfg.template"
                        fi

                        if [ -z "\$TEMPLATE_FILE" ]; then
                            echo "ERROR: ssh.cfg.template not found in root, templates/, or ansible/ folders."
                            exit 1
                        fi

                        # Generate config and set permissions
                        sed "s/BASTION_IP_PLACEHOLDER/${BASTION_IP}/g" \$TEMPLATE_FILE > \$HOME/.ssh/config
                        
                        chmod 600 \$HOME/.ssh/config
                        chmod 400 \$WORKSPACE/sandeepkey.pem

                        # Initialize agent and add key
                        eval \$(ssh-agent -s)
                        ssh-add \$WORKSPACE/sandeepkey.pem
                        ssh-add -l
                    """
                }
            }
        }
