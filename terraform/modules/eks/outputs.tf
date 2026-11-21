output "cluster_name" { value = aws_eks_cluster.this.name }
output "cluster_endpoint" { value = aws_eks_cluster.this.endpoint }
output "cluster_ca_data" { value = aws_eks_cluster.this.certificate_authority[0].data }
output "cluster_security_group_id" { value = aws_security_group.cluster.id }
output "node_role_arn" { value = aws_iam_role.node.arn }
output "oidc_provider_arn" { value = try(aws_iam_openid_connect_provider.this[0].arn, "") }
output "irsa_role_arn" { value = try(aws_iam_role.irsa[0].arn, "") }

output "cluster_autoscaler_role_arn" {
  value = try(aws_iam_role.cluster_autoscaler[0].arn, "")
}

output "node_group_asg_name" {
  value = try(aws_eks_node_group.this[0].resources[0].autoscaling_groups[0].name, "")
}

output "eks_cluster_security_group_id" {
  value = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "ebs_csi_role_arn" {
  value = try(aws_iam_role.ebs_csi[0].arn, "")
}
