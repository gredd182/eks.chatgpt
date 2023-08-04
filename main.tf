provider "aws" {
  region = "us-west-2"  # Replace with your desired AWS region
}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Create public subnets
resource "aws_subnet" "public" {
  count             = 2
  cidr_block        = "10.0.${count.index + 1}.0/24"
  vpc_id            = aws_vpc.main.id
  availability_zone = "us-west-2a"  # Replace with your desired availability zone
}

# Create EKS cluster
resource "aws_eks_cluster" "example" {
  name = "my-eks-cluster"
  role_arn = "arn:aws:iam::123456789012:role/eks-cluster-role"  # Replace with your IAM role ARN for EKS

  vpc_config {
    subnet_ids = aws_subnet.public[*].id

    endpoint_private_access = true
    endpoint_public_access  = false
  }
}

# Create IAM role for EKS worker nodes
resource "aws_iam_role" "eks_node_group" {
  name = "eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach necessary policies to the IAM role
resource "aws_iam_role_policy_attachment" "eks_node_group" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group.name

  depends_on = [aws_eks_cluster.example]
}

resource "aws_iam_role_policy_attachment" "eks_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group.name

  depends_on = [aws_eks_cluster.example]
}

resource "aws_iam_role_policy_attachment" "efs" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group.name

  depends_on = [aws_eks_cluster.example]
}

# Create EKS worker node group
module "eks_worker_nodes" {
  source = "terraform-aws-modules/eks/aws//modules/worker_nodes"

  cluster_name = aws_eks_cluster.example.name
  subnets      = aws_subnet.public[*].id

  additional_security_group_ids = []  # Add additional security group IDs if needed
  instance_types                = ["t2.micro"]  # Replace with your desired instance types
  desired_capacity             = 2
  min_size                     = 2
  max_size                     = 2
  additional_security_group_ids = []  # Add additional security group IDs if needed

  # IAM role for EKS worker nodes
  node_groups_launch_template = [
    {
      name           = "my-node-group"
      instance_type  = "t2.micro"  # Replace with your desired instance type
      spot_price     = "0.0"
      security_groups = []  # Add security group IDs if needed
      iam_instance_profile = {
        name = aws_iam_instance_profile.eks_node_group.name
      }
    }
  ]
}

resource "aws_iam_instance_profile" "eks_node_group" {
  name = "eks-node-group-instance-profile"
  role = aws_iam_role.eks_node_group.name
}

output "kubeconfig" {
  value = aws_eks_cluster.example.kubeconfig
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.example.endpoint
}

output "eks_cluster_oidc_issuer_url" {
  value = aws_eks_cluster.example.identity[0].oidc[0].issuer
}
