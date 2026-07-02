[bastion]
bastion_host ansible_host=${bastion_ip} ansible_user=ubuntu

[sonarqube_nodes]
sonar_node_1 ansible_host=${active_ip} ansible_user=ubuntu
sonar_node_2 ansible_host=${passive_ip} ansible_user=ubuntu

[all:vars]
# Tell Ansible to route all traffic to the sonarqube_nodes through the Bastion Host
ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -q -i {{ lookup(\'env\', \'KEY_FILE\') }} -o StrictHostKeyChecking=no ubuntu@${bastion_ip}"'
ansible_ssh_private_key_file="{{ lookup('env', 'KEY_FILE') }}"
ansible_ssh_extra_args='-o StrictHostKeyChecking=no'

# Architectural variables for your playbooks
efs_dns_name=${efs_dns}
