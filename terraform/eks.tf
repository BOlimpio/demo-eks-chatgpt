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

module "eks" {
  source  = "terraform-aws-modules/eks/aws"

  cluster_name    = var.cluster_name

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"

  }

  eks_managed_node_groups = {
    one = {
      name = "chatgpt-ng-1"

      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 3
      desired_size = 2
    }
  }

  depends_on = [module.vpc]
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