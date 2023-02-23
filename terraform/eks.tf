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

//ToDo USE EKS BLUEPRINTS

module "eks_blueprints" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints"

  # EKS CLUSTER
  cluster_version    = "1.24"                                         # EKS Cluster Version
  vpc_id             = module.vpc.vpc_id                              # Enter VPC ID
  private_subnet_ids = module.vpc.private_subnets                     # Enter Private Subnet IDs

  # EKS Addons
  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  # EKS MANAGED NODE GROUPS
  managed_node_groups = {
    mng = {
      node_group_name = "chatgpt-ng-1"
      instance_types  = ["t3.medium"]
      subnet_ids      = module.vpc.private_subnets  # Mandatory Public or Private Subnet IDs
      disk_size       = 100 # disk_size will be ignored when using Launch Templates
      capacity_type   = "ON_DEMAND"  # ON_DEMAND or SPOT
      ami_type        = "AL2_x86_64" # Amazon Linux 2(AL2_x86_64), AL2_x86_64_GPU, AL2_ARM_64, BOTTLEROCKET_x86_64, BOTTLEROCKET_ARM_64

      # Node Group scaling configuration
      desired_size    = 2
      max_size        = 3
      min_size        = 1
    }
  }

  depends_on = [module.vpc]
}

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

  depends_on = [
    module.eks_blueprints,
    module.vpc,
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
    module.eks_blueprints,
    module.vpc,
  ]
}