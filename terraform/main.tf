provider "aws" {
  region = "ap-south-1"
}

# Default VPC
data "aws_vpc" "default" {
  default = true
}

# Default subnets
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# IAM role for EKS cluster (required)
resource "aws_iam_role" "eks_cluster_role" {
  name = "reviewapp-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# EKS Cluster using DEFAULT VPC + SUBNETS
resource "aws_eks_cluster" "reviewapp_cluster" {
  name     = "reviewapp-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = data.aws_subnets.default.ids
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}
resource "aws_ec2_tag" "eks_subnet_tags" {
  for_each = toset(data.aws_subnets.default.ids)

  resource_id = each.value
  key         = "kubernetes.io/cluster/reviewapp-cluster"
  value       = "shared"
}

# IAM role for Node Group
resource "aws_iam_role" "eks_node_role" {
  name = "reviewapp-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach managed policies to Node Role
resource "aws_iam_role_policy_attachment" "node_group_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "registry_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Managed Node Group
resource "aws_eks_node_group" "reviewapp_nodes" {
  cluster_name    = aws_eks_cluster.reviewapp_cluster.name
  node_group_name = "reviewapp-nodes"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = data.aws_subnets.default.ids

  scaling_config {
    desired_size = 1 
    max_size     = 1 
    min_size     = 1
  }

  instance_types = ["t3.medium"] # cheap for learning/demo

  depends_on = [
    aws_eks_cluster.reviewapp_cluster
  ]
}




