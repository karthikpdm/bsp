# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#     }
#     kubernetes = {
#       source  = "hashicorp/kubernetes"
#     }
#     helm = {
#       source  = "hashicorp/helm"
#     }
#     kubectl = {
#       source  = "gavinbunney/kubectl"  # This is the key addition
#       version = "~> 1.14"
#     }
#     tls = {
#       source  = "hashicorp/tls"
#     }
#   }
# }