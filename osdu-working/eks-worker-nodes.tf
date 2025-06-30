#  Worker Node role
resource "aws_iam_role" "osdu-ir-worker-node-role" {
  name = "osdu-ir-worker-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "osdu-ir-worker-node-role"
  }
}

resource "aws_iam_role_policy_attachment" "osdu-ir-worker-node-policy-attach" {
  role       = aws_iam_role.osdu-ir-worker-node-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "osdu-ir-eks-cni-policy-attach" {
  role       = aws_iam_role.osdu-ir-worker-node-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "osdu-ir-eks-registry-policy-attach" {
  role       = aws_iam_role.osdu-ir-worker-node-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "osdu-ir-node-profile" {
  name = "osdu-ir-node-profile"
  role = aws_iam_role.osdu-ir-worker-node-role.name
}

output "osdu-ir-worker-node-arn" {
  value = aws_iam_role.osdu-ir-worker-node-role.arn
}

# Creation of the EC2 instance for hosting Istio + Keycloak
resource "aws_eks_node_group" "osdu_ir_istio_node" {
  cluster_name    = aws_eks_cluster.osdu-ir-eks-cluster.name
  node_group_name = "osdu-ir-istio-worker-node"
  node_role_arn   = aws_iam_role.osdu-ir-worker-node-role.arn
  subnet_ids = [
    aws_subnet.osdu-ir-private[0].id,
    aws_subnet.osdu-ir-private[1].id
  ]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  instance_types = [var.instance_type]

  ami_type      = "AL2_x86_64"
  capacity_type = "ON_DEMAND"

  # Add labels for node scheduling
  labels = {
    "node-role"     = "osdu-istio-keycloak"
    "workload-type" = "istio"
    "component"     = "service-mesh"
  }

  # Add taints to ensure only Istio/Keycloak pods run here
  taint {
    key    = "node-role"
    value  = "osdu-istio-keycloak"
    effect = "NO_SCHEDULE"
  }

  tags = {
    Name                                        = "osdu-ir-istio-worker-node"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }

  depends_on = [
    aws_eks_cluster.osdu-ir-eks-cluster,
    aws_iam_role_policy_attachment.osdu-ir-worker-node-policy-attach,
    aws_iam_role_policy_attachment.osdu-ir-eks-cni-policy-attach,
    aws_iam_role_policy_attachment.osdu-ir-eks-registry-policy-attach
  ]
}

# Creation of the EC2 instance for hosting MinIO + PostgreSQL + Elasticsearch + RabbitMQ
resource "aws_eks_node_group" "osdu_ir_backend_node" {
  cluster_name    = aws_eks_cluster.osdu-ir-eks-cluster.name
  node_group_name = "osdu-ir-backend-worker-node"
  node_role_arn   = aws_iam_role.osdu-ir-worker-node-role.arn
  subnet_ids = [
    aws_subnet.osdu-ir-private[0].id,
    aws_subnet.osdu-ir-private[1].id
  ]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  instance_types = [var.instance_type]

  ami_type      = "AL2_x86_64"
  capacity_type = "ON_DEMAND"

  # Add labels for node scheduling
  labels = {
    "node-role"         = "osdu-backend"
    "workload-type"     = "database"
    "component"         = "backend-services"
    "storage-optimized" = "true"
  }

  # Add taints for backend workloads
  taint {
    key    = "node-role"
    value  = "osdu-backend"
    effect = "NO_SCHEDULE"
  }

  tags = {
    Name                                        = "osdu-ir-backend-worker-node"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }

  depends_on = [
    aws_eks_cluster.osdu-ir-eks-cluster,
    aws_iam_role_policy_attachment.osdu-ir-worker-node-policy-attach,
    aws_iam_role_policy_attachment.osdu-ir-eks-cni-policy-attach,
    aws_iam_role_policy_attachment.osdu-ir-eks-registry-policy-attach
  ]
}

# Creation of the EC2 instance for hosting OSDU Microservices + Airflow + Redis
resource "aws_eks_node_group" "osdu_ir_frontend_node" {
  cluster_name    = aws_eks_cluster.osdu-ir-eks-cluster.name
  node_group_name = "osdu-ir-frontend-worker-node"
  node_role_arn   = aws_iam_role.osdu-ir-worker-node-role.arn
  subnet_ids = [
    aws_subnet.osdu-ir-private[0].id,
    aws_subnet.osdu-ir-private[1].id
  ]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  instance_types = [var.instance_type]

  ami_type      = "AL2_x86_64"
  capacity_type = "ON_DEMAND"

  # Add labels for node scheduling
  labels = {
    "node-role"         = "osdu-frontend"
    "workload-type"     = "microservices"
    "component"         = "osdu-apis"
    "compute-optimized" = "true"
  }

  # Add taints for frontend workloads
  taint {
    key    = "node-role"
    value  = "osdu-frontend"
    effect = "NO_SCHEDULE"
  }

  tags = {
    Name                                        = "osdu-ir-frontend-worker-node"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }

  depends_on = [
    aws_eks_cluster.osdu-ir-eks-cluster,
    aws_iam_role_policy_attachment.osdu-ir-worker-node-policy-attach,
    aws_iam_role_policy_attachment.osdu-ir-eks-cni-policy-attach,
    aws_iam_role_policy_attachment.osdu-ir-eks-registry-policy-attach
  ]
}

# Linux-compatible labeling for Istio nodes (backup/verification)
resource "null_resource" "label_and_taint_istio_keycloak_nodes" {
  depends_on = [
    aws_eks_node_group.osdu_ir_istio_node
  ]

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      echo "Updating kubeconfig..."
      aws eks update-kubeconfig --region us-east-1 --name osdu-ir-eks-cluster
      
      echo "Getting Istio nodes..."
      nodes=$(kubectl get nodes -l eks.amazonaws.com/nodegroup=osdu-ir-istio-worker-node -o jsonpath="{.items[*].metadata.name}")
      
      if [ -n "$nodes" ]; then
        for node in $nodes; do
          echo "Labeling and tainting node: $node"
          kubectl label node $node node-role=osdu-istio-keycloak --overwrite
          kubectl taint node $node node-role=osdu-istio-keycloak:NoSchedule --overwrite || true
        done
        echo "Istio nodes labeled and tainted successfully"
      else
        echo "No Istio nodes found"
      fi
    EOT
    
    interpreter = ["/bin/bash", "-c"]
  }
}

# Linux-compatible labeling for Backend nodes (backup/verification)
resource "null_resource" "label_and_taint_backend_nodes" {
  depends_on = [
    aws_eks_node_group.osdu_ir_backend_node
  ]

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      echo "Updating kubeconfig..."
      aws eks update-kubeconfig --region us-east-1 --name osdu-ir-eks-cluster
      
      echo "Getting backend nodes..."
      nodes=$(kubectl get nodes -l eks.amazonaws.com/nodegroup=osdu-ir-backend-worker-node -o jsonpath="{.items[*].metadata.name}")
      
      if [ -n "$nodes" ]; then
        for node in $nodes; do
          echo "Labeling and tainting node: $node"
          kubectl label node $node node-role=osdu-backend --overwrite
          kubectl taint node $node node-role=osdu-backend:NoSchedule --overwrite || true
        done
        echo "Backend nodes labeled and tainted successfully"
      else
        echo "No backend nodes found"
      fi
    EOT
    
    interpreter = ["/bin/bash", "-c"]
  }
}

# Linux-compatible labeling for Frontend nodes (backup/verification)
resource "null_resource" "label_and_taint_frontend_nodes" {
  depends_on = [
    aws_eks_node_group.osdu_ir_frontend_node
  ]

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      echo "Updating kubeconfig..."
      aws eks update-kubeconfig --region us-east-1 --name osdu-ir-eks-cluster
      
      echo "Getting frontend nodes..."
      nodes=$(kubectl get nodes -l eks.amazonaws.com/nodegroup=osdu-ir-frontend-worker-node -o jsonpath="{.items[*].metadata.name}")
      
      if [ -n "$nodes" ]; then
        for node in $nodes; do
          echo "Labeling and tainting node: $node"
          kubectl label node $node node-role=osdu-frontend --overwrite
          kubectl taint node $node node-role=osdu-frontend:NoSchedule --overwrite || true
        done
        echo "Frontend nodes labeled and tainted successfully"
      else
        echo "No frontend nodes found"
      fi
    EOT
    
    interpreter = ["/bin/bash", "-c"]
  }
}