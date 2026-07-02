[all_nodes]
sonar_node_active ansible_host=${active_ip}
sonar_node_passive ansible_host=${passive_ip}

[sonar_active]
sonar_node_active ansible_host=${active_ip}

[sonar_passive]
sonar_node_passive ansible_host=${passive_ip}

[all_nodes:vars]
ansible_user=ubuntu
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -q ubuntu@${bastion_ip} -o StrictHostKeyChecking=no"'
