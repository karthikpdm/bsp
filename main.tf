module "iam" {
  source = "./modules/iam"

env      = var.env
tags     = var.tags

  
  
 
}

module "security_groups" {
  source = "./modules/sg"

  env                   = var.env
  master_ingress_rules  = var.master_ingress_rules
  master_egress_rules   = var.master_egress_rules
  workers_ingress_rules = var.workers_ingress_rules
  workers_egress_rules  = var.workers_egress_rules
  tags = var.tags

}
###########################################################################################################

# module "vpc" {

#   source = "./modules/vpc"

#   vpc_cidr_block = var.vpc_cidr_block
#   private_subnet_az1_cidr = var.private_subnet_az1_cidr
#   private_subnet_az2_cidr = var.private_subnet_az2_cidr
#   public_subnet_az1_cidr  = var.public_subnet_az1_cidr
#   public_subnet_az2_cidr  = var.public_subnet_az2_cidr
#   env                     = var.env
#   tags = var.tags

# }

###########################################################################################################

module "eks" {
  source = "./modules/eks"
   

########################################################################################################### 
  env                           = var.env
  region                        = var.region
  eks_version                   = var.eks_version
  master_role_arn               = module.iam.eks-master-role
  eks_master_sg_id              = module.security_groups.eks_master_sg_id

###############################  worker ###########################################################################
  worker_role_arn               = module.iam.worker_role_arn
  # disk_size                     = var.disk_size
  # instance_type                 = var.instance_type
  tags = var.tags

###############################  istio ###########################################################################

  istio_version                 = var.istio_version
  



}




   




