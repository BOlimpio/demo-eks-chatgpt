module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.vpc_name
  cidr = var.vpc_cidr
  azs = local.azs
  enable_ipv6 = true
  enable_nat_gateway = false
  single_nat_gateway = true
  private_subnets = var.private_subnets
  public_subnets = var.public_subnets
  tags = var.tags
}

module "eks_managed_node_group" {
  source = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"

  name            = "separate-eks-mng"
  cluster_name    = var.cluster_name
  cluster_version = "1.24"

  subnet_ids = module.vpc.private_subnets

  // The following variables are necessary if you decide to use the module outside of the parent EKS module context.
  // Without it, the security groups of the nodes are empty and thus won't join the cluster.
  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
  vpc_security_group_ids            = [module.eks.node_security_group_id]

  // Note: `disk_size`, and `remote_access` can only be set when using the EKS managed node group default launch template
  // This module defaults to providing a custom launch template to allow for custom security groups, tag propagation, etc.
  // use_custom_launch_template = false
  // disk_size = 50
  //
  //  # Remote access cannot be specified with a launch template
  //  remote_access = {
  //    ec2_ssh_key               = module.key_pair.key_pair_name
  //    source_security_group_ids = [aws_security_group.remote_access.id]
  //  }

  min_size     = 1
  max_size     = 4
  desired_size = 2

  instance_types = ["t3.small"]
  capacity_type  = "SPOT"

  labels = {
    Environment = "test"
    GithubRepo  = "terraform-aws-eks"
    GithubOrg   = "terraform-aws-modules"
  }

  taints = {
    dedicated = {
      key    = "dedicated"
      value  = "gpuGroup"
      effect = "NO_SCHEDULE"
    }
  }

  tags = var.tags
}

# module "eks" {
#   source = "terraform-aws-modules/eks/aws"

#   cluster_name = var.cluster_name
#   subnet_ids = module.vpc.private_subnets
#   vpc_id = module.vpc.vpc_id
#   cluster_endpoint_public_access = true
#   tags = var.tags
#   eks_managed_node_groups = {
#     one = {
#       name = "chatgpt-ng-1"

#       instance_types = ["t3.small"]

#       min_size     = 1
#       max_size     = 3
#       desired_size = 2
#     }
#   }

#   depends_on = [module.vpc]
# }

# Deploy Prometheus using Helm
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  namespace  = "monitoring"

  # Set the values for the Prometheus Helm chart
  values = [
    file("${path.module}/prometheus.yaml"),
  ]
}

# Deploy Grafana using Helm
resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = "monitoring"

  # Set the values for the Grafana Helm chart
  values = [
    file("${path.module}/grafana.yaml"),
  ]

  # Add a dependency on the Prometheus deployment
  depends_on = [
    helm_release.prometheus,
  ]
}