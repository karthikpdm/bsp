# Roles for the EBS CSI Driver
data "aws_iam_policy_document" "osdu-ir-csi" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.osdu-ir-openid-provider.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.osdu-ir-openid-provider.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "osdu-ir-ebs-csi-driver-role" {
  assume_role_policy = data.aws_iam_policy_document.osdu-ir-csi.json
  name               = "osdu-ir-ebs-csi-driver-role"
}

resource "aws_iam_role_policy_attachment" "osdu-ir-ebs-csi-driver-policy" {
  role       = aws_iam_role.osdu-ir-ebs-csi-driver-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

data "tls_certificate" "osdu-ir-certificate" {
  url = aws_eks_cluster.osdu-ir-eks-cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "osdu-ir-openid-provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.osdu-ir-certificate.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.osdu-ir-eks-cluster.identity[0].oidc[0].issuer
}


resource "aws_eks_addon" "osdu-ir-csi-addon" {
  cluster_name             = var.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = var.csi_ebs_driver_version
  service_account_role_arn = aws_iam_role.osdu-ir-ebs-csi-driver-role.arn

  depends_on = [
    aws_eks_node_group.osdu_ir_istio_node,
    aws_eks_node_group.osdu_ir_backend_node,
    aws_eks_node_group.osdu_ir_frontend_node
  ]
}
