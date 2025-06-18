# Data sources for existing VPC components
data "aws_vpc" "existing_vpc" {
  filter {
    name   = "tag:Name"
    values = ["bsp-vpc-${var.env}"]
  }
}

data "aws_subnet" "private_subnet_az1" {
  filter {
    name   = "tag:Name"
    values = ["bsp-private-subnet-az1-${var.env}"]
  }
}

data "aws_subnet" "private_subnet_az2" {
  filter {
    name   = "tag:Name"
    values = ["bsp-private-subnet-az2-${var.env}"]
  }
}

data "aws_subnet" "public_subnet_az1" {
  filter {
    name   = "tag:Name"
    values = ["bsp-public-subnet-az1-${var.env}"]  
  }
}

data "aws_subnet" "public_subnet_az2" {
  filter {
    name   = "tag:Name"
    values = ["bsp-public-subnet-az2-${var.env}"]  
  }
}




# entry for the cluster access
resource "aws_eks_access_entry" "cluster_admin" {
  cluster_name      = aws_eks_cluster.eks.name
  principal_arn     = var.master_role_arn  # Use your existing EKS cluster role
#   kubernetes_groups = ["system:masters"]
  kubernetes_groups = []
  type             = "STANDARD"

  depends_on = [aws_eks_cluster.eks]
}



# # Add cluster admin policy instead
# resource "aws_eks_access_policy_association" "cluster_admin_policy" {
#   cluster_name  = aws_eks_cluster.eks.name
#   principal_arn = var.master_role_arn
  
#   policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  
#   access_scope {
#     type = "cluster"
#   }

#   depends_on = [aws_eks_access_entry.cluster_admin]
# }
###########################################################################################################

# Creating EKS Cluster
resource "aws_eks_cluster" "eks" {
  name     = "bsp-eks-cluster-${var.env}"
  role_arn = var.master_role_arn
  version  = var.eks_version

  vpc_config {
    # subnet_ids              = [data.aws_subnet.private_subnet_az1.id, data.aws_subnet.private_subnet_az2.id]
    subnet_ids = [
      data.aws_subnet.private_subnet_az1.id, 
      data.aws_subnet.private_subnet_az2.id,
      data.aws_subnet.public_subnet_az1.id,   # Add public subnets
      data.aws_subnet.public_subnet_az2.id    # Add public subnets
    ]
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]  # Allow access from anywhere
    security_group_ids      = [var.eks_master_sg_id]
  }

  # Enable all log types
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }
  
#   encryption_config {
#     provider {
#       key_arn = aws_kms_key.eks_secrets.arn
#     }
#     resources = ["secrets"]
#   }

  # Ensure that CloudWatch log group is created before the EKS cluster
#   depends_on = [aws_cloudwatch_log_group.eks_cluster]

  

   tags = merge(
    var.tags,
    {
      Name = "bsp-eks-cluster-${var.env}"
    }
  )
  
#   lifecycle {
#     prevent_destroy = true
#   }
}


###########################################################################################################



data "aws_eks_addon_version" "vpc-cni-default" {
  addon_name         = "vpc-cni"
  kubernetes_version = aws_eks_cluster.eks.version
}

resource "aws_eks_addon" "vpc-cni" {
  addon_name        = "vpc-cni"
  addon_version     = data.aws_eks_addon_version.vpc-cni-default.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  cluster_name      = aws_eks_cluster.eks.name
  
  configuration_values = jsonencode({
    "enableNetworkPolicy" = "true"
  })

   # Ensure proper creation order
  depends_on = [
    aws_eks_cluster.eks,
    aws_eks_node_group.node-grp
  ]

    tags = var.tags

}

###########################################################################################################

data "aws_eks_addon_version" "kube-proxy-default" {
  addon_name         = "kube-proxy"
  kubernetes_version = aws_eks_cluster.eks.version
}

resource "aws_eks_addon" "kube-proxy" {
  addon_name        = "kube-proxy"
  addon_version     = data.aws_eks_addon_version.kube-proxy-default.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  cluster_name      = aws_eks_cluster.eks.name

  depends_on = [
    aws_eks_cluster.eks,
    aws_eks_node_group.node-grp
  ]

  tags = var.tags

}

###########################################################################################################


###########################################################################################################

# IAM Role for EBS CSI Driver
resource "aws_iam_role" "ebs_csi_driver_role" {
  name = "bsp-eks-ebs-csi-driver-role-${var.env}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# Custom IAM Policy for EBS CSI Driver (more reliable than AWS managed policy)
resource "aws_iam_policy" "ebs_csi_driver_policy" {
  name        = "bsp-eks-ebs-csi-driver-policy-${var.env}"
  description = "IAM policy for EBS CSI driver"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSnapshot",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:ModifyVolume",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInstances",
          "ec2:DescribeSnapshots",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes",
          "ec2:DescribeVolumesModifications"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"
        ]
        Resource = [
          "arn:aws:ec2:*:*:volume/*",
          "arn:aws:ec2:*:*:snapshot/*"
        ]
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = [
              "CreateVolume",
              "CreateSnapshot"
            ]
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteTags"
        ]
        Resource = [
          "arn:aws:ec2:*:*:volume/*",
          "arn:aws:ec2:*:*:snapshot/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateVolume"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:RequestedRegion" = "*"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteVolume"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "ec2:ResourceTag/ebs.csi.aws.com/cluster" = "true"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteSnapshot"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "ec2:ResourceTag/CSIVolumeSnapshotName" = "*"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# Attach the custom EBS CSI Driver policy to the role
resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy" {
  policy_arn = aws_iam_policy.ebs_csi_driver_policy.arn
  role       = aws_iam_role.ebs_csi_driver_role.name
}

###########################################################################################################

# EBS CSI Driver Add-on
data "aws_eks_addon_version" "ebs-csi-default" {
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = aws_eks_cluster.eks.version
}

resource "aws_eks_addon" "ebs-csi" {
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = data.aws_eks_addon_version.ebs-csi-default.version
  cluster_name             = aws_eks_cluster.eks.name
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn = aws_iam_role.ebs_csi_driver_role.arn

  configuration_values = jsonencode({
    controller = {
      tolerations = [
        {
          key      = "CriticalAddonsOnly"
          operator = "Exists"
        }
      ]
    }
  })

  depends_on = [
    aws_eks_cluster.eks,
    aws_eks_node_group.node-grp,
    aws_iam_openid_connect_provider.eks,
    aws_iam_role_policy_attachment.ebs_csi_driver_policy
  ]

  tags = var.tags
}

###########################################################################################################
###########################################################################################################
data "aws_eks_addon_version" "coredns-default" {
  addon_name         = "coredns"
  kubernetes_version = aws_eks_cluster.eks.version
}

resource "aws_eks_addon" "coredns" {
  addon_name        = "coredns"
  addon_version     = data.aws_eks_addon_version.coredns-default.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  cluster_name      = aws_eks_cluster.eks.name

  depends_on = [
    aws_eks_cluster.eks,
    aws_eks_node_group.node-grp
  ]

  tags = var.tags


}

#######################################################################
# OIDC Identity Provider
#######################################################################

data "tls_certificate" "eks" {
  url = aws_eks_cluster.eks.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks.identity[0].oidc[0].issuer
  
  tags = var.tags
}
###########################################################################################################
