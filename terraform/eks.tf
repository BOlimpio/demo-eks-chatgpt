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

//ToDo create eks cluster and worker nodes with native resources

module "eks_blueprints" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints?ref=v4.21.0"

  cluster_name    = "chatGPT-cluster"

  # EKS Cluster VPC and Subnet mandatory config
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets

  # EKS CONTROL PLANE VARIABLES
  cluster_version = "1.24"

  # EKS MANAGED NODE GROUPS
  managed_node_groups = {
    mg_5 = {
      node_group_name = "ng_chatGPT"
      instance_types  = ["t3.medium"]
      subnet_ids      = module.vpc.private_subnets
    }
  }

  depends_on = [
    module.vpc,
  ]

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