[sonar_active]
${active_instance_id} ansible_host=${active_ip} ansible_user=ubuntu

[sonar_passive]
${passive_instance_id} ansible_host=${passive_ip} ansible_user=ubuntu

[all_nodes:children]
sonar_active
sonar_passive

[all_nodes:vars]
efs_dns_name=${efs_dns}

# Force the background proxy wrapper to reference our locally generated workspace configurations
ansible_ssh_common_args='-o ProxyCommand="env AWS_SHARED_CREDENTIALS_FILE=.aws/credentials AWS_CONFIG_FILE=.aws/config aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters port=%p" -o StrictHostKeyChecking=no'
