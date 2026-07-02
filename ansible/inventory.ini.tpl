[bastion]
bastion_host ansible_host=<YOUR_BASTION_PUBLIC_IP> ansible_user=ubuntu

[sonarqube_nodes]
sonar_node_active  ansible_host=10.0.3.x  ansible_user=ubuntu
sonar_node_passive ansible_host=10.0.4.x  ansible_user=ubuntu

[all:vars]
# This magic line forces Ansible to tunnel through the bastion to reach the private nodes
ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -q ubuntu@<YOUR_BASTION_PUBLIC_IP> -i /path/to/jenkins-ssh-key"'
