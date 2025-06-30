# Command to run kubeconfig
# aws eks update-kubeconfig --region us-east-1 --name osdu-ir-eks-cluster

# EKS Cluster role
resource "aws_iam_role" "osdu-ir-eks-cluster-role" {
  name = "osdu-ir-eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "eks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "osdu-ir-eks-cluster-role"
  }
}

resource "aws_iam_role_policy_attachment" "osdu-ir-eks-cluster-policy-attach" {
  role       = aws_iam_role.osdu-ir-eks-cluster-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "osdu-ir-eks-service-policy-attach" {
  role       = aws_iam_role.osdu-ir-eks-cluster-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

output "osdu-ir-eks-cluster-arn" {
  value = aws_iam_role.osdu-ir-eks-cluster-role.arn
}

# Creating the cluster
resource "aws_eks_cluster" "osdu-ir-eks-cluster" {
  name     = var.cluster_name
  version  = var.eks_version
  role_arn = aws_iam_role.osdu-ir-eks-cluster-role.arn

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true
    subnet_ids = [
      aws_subnet.osdu-ir-private[0].id,
      aws_subnet.osdu-ir-private[1].id
    ]
  }

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator"
  ]

  depends_on = [
    aws_iam_role_policy_attachment.osdu-ir-eks-cluster-policy-attach,
    aws_iam_role_policy_attachment.osdu-ir-eks-service-policy-attach
  ]

  tags = {
    Name = "osdu-ir-eks-cluster"
  }
}
