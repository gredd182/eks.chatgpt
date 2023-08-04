provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags       = var.tags
}

resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  cidr_block        = var.public_subnet_cidrs[count.index]
  vpc_id            = aws_vpc.main.id
  availability_zone = var.availability_zones[count.index]
  tags              = merge(var.tags, { "Name" = "public-subnet-${count.index + 1}" })
}

resource "aws_eks_cluster" "example" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids = aws_subnet.public[*].id
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster]
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  roles      = [aws_iam_role.eks_cluster.name]
}

resource "aws_iam_role" "eks_cluster" {
  name = "eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_launch_configuration" "example" {
  name                 = "eks-launch-config"
  image_id             = var.instance_ami
  instance_type        = var.instance_type
  security_groups      = [aws_security_group.eks_cluster.id]
  iam_instance_profile = aws_iam_instance_profile.example.arn
  key_name             = var.ssh_key_name

  lifecycle {
    create_before_destroy = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "example" {
  name                 = "eks-asg"
  launch_configuration = aws_launch_configuration.example.id
  min_size             = var.min_nodes
  max_size             = var.max_nodes
  desired_capacity     = var.desired_capacity
  vpc_zone_identifier  = aws_subnet.public[*].id
  tags = [
    {
      key                 = "Name"
      value               = "eks-node"
      propagate_at_launch = true
    },
  ]
}

resource "aws_security_group" "eks_cluster" {
  name_prefix = "eks-cluster-sg-"

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_instance_profile" "example" {
  name = "eks-instance-profile"

  role = aws_iam_role.eks_instance_profile.name
}

resource "aws_iam_role" "eks_instance_profile" {
  name = "eks-instance-profile-role"

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

output "kubeconfig" {
  value = aws_eks_cluster.example.kubeconfig
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.example.endpoint
}

output "eks_cluster_oidc_issuer_url" {
  value = aws_eks_cluster.example.identity[0].oidc[0].issuer
}
