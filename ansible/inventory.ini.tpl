[sonar_active]
${active_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa

[sonar_passive]
${passive_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa

[all_nodes:children]
sonar_active
sonar_passive

[all_nodes:vars]
efs_dns_name=${efs_dns}
