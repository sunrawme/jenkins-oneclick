[sonar_active]
${active_instance_id} ansible_host=${active_ip} ansible_user=ubuntu

[sonar_passive]
${passive_instance_id} ansible_host=${passive_ip} ansible_user=ubuntu

[all_nodes:children]
sonar_active
sonar_passive

[all_nodes:vars]
efs_dns_name=${efs_dns}

# Route traffic directly over AWS SSM using custom injected credentials
ansible_ssh_common_args='-o ProxyCommand="aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters port=%p" -o StrictHostKeyChecking=no'
