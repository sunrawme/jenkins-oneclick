[sonar_active]
${active_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa

[sonar_passive]
${passive_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa

[all_nodes:children]
sonar_active
sonar_passive

[all_nodes:vars]
efs_dns_name=${efs_dns}

# Instructs Ansible to automatically transparently tunnel SSH traffic through the Bastion Host
ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -q ubuntu@${bastion_ip} -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no" -o StrictHostKeyChecking=no'
