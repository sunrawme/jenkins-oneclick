[sonar_active]
${active_ip} ansible_user=ubuntu

[sonar_passive]
${passive_ip} ansible_user=ubuntu

[all_nodes:children]
sonar_active
sonar_passive

[all_nodes:vars]
efs_dns_name=${efs_dns}

# Route traffic directly over AWS SSM instead of an EC2 Bastion node
# Route traffic directly over AWS SSM using custom injected credentials
ansible_ssh_common_args='-o ProxyCommand="env AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters port=%p" -o StrictHostKeyChecking=no'
