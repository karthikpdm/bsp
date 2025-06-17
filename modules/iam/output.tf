# outputs.tf

# VPC Outputs
output "eks-master-role" {
  description = "ID of the VPC"
  value       = aws_iam_role.master.arn
}

output "worker_role_arn" {
  value = aws_iam_role.worker.arn
}


