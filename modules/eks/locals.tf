locals {
  node-userdata = <<USERDATA
#!/bin/bash -xe

# Update package lists
apt-get update

# Install required packages
apt-get install -y awscli

# Bootstrap the node to join the EKS cluster
/etc/eks/bootstrap.sh ${aws_eks_cluster.eks.name}

# Install SSM Agent (if not already installed)
if ! systemctl is-active --quiet amazon-ssm-agent; then
    snap install amazon-ssm-agent --classic
    systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
    systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
fi

# Ensure SSM Agent is running
systemctl status snap.amazon-ssm-agent.amazon-ssm-agent.service

USERDATA
}