[bastion]
bastion_host ansible_host=${bastion_ip} ansible_user=ubuntu

[sonarqube_nodes]
sonar_node_active  ansible_host=${active_ip} ansible_user=ubuntu
sonar_node_passive ansible_host=${passive_ip} ansible_user=ubuntu

[all:vars]
# Using {{ ansible_ssh_private_key_file }} ensures Ansible handles the credential mapping automatically
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -W %h:%p -q ubuntu@${bastion_ip} -i {{ ansible_ssh_private_key_file }}"'
