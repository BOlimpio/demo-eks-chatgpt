//ToDo create eks cluster and worker nodes with native resources
resource "aws_eks_cluster" "chatgpt_cluster" {
  name = "eks-chatgpt-cluster"
  role_arn = aws_iam_role.eks_cluster.arn
  vpc_config {
    subnet_ids = module.vpc.private_subnets
  }
  depends_on = [module.vpc]
}

resource "aws_iam_role" "eks_cluster" {
  name = "eks-cluster"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_eks_node_group" "ng_chatgpt" {
  cluster_name    = aws_eks_cluster.chatgpt_cluster.name
  node_group_name = "my-worker-node-group"
  node_role_arn   = aws_iam_role.eks_worker.arn
  subnet_ids      = module.vpc.private_subnets
  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }
  depends_on = [aws_eks_cluster.chatgpt_cluster, aws_iam_role.eks_worker]
}

resource "aws_iam_role" "eks_worker" {
  name = "eks-worker"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_worker.name
}

resource "aws_iam_instance_profile" "eks_worker" {
  name = "eks-worker"
  role = aws_iam_role.eks_worker.name
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
    aws_eks_cluster.chatgpt_cluster,
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
    aws_eks_cluster.chatgpt_cluster,
  ]
}