data "aws_eks_cluster" "osdu-eks-cluster" {
  name = var.cluster_name
  depends_on = [
    aws_eks_cluster.osdu-ir-eks-cluster
  ]
}

data "aws_eks_cluster_auth" "osdu-eks-cluster-auth" {
  name = var.cluster_name
}


provider "kubernetes" {
  host                   = data.aws_eks_cluster.osdu-eks-cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.osdu-eks-cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.osdu-eks-cluster-auth.token
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.osdu-eks-cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.osdu-eks-cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.osdu-eks-cluster-auth.token
  }
}
