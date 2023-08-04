variable "aws_region" {
  description = "AWS region for the EKS cluster."
}

variable "cluster_name" {
  description = "Name of the EKS cluster."
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks for public subnets."
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones for public subnets."
}

variable "instance_type" {
  description = "EC2 instance type for the EKS nodes."
}

variable "desired_capacity" {
  description = "Desired capacity of the node group."
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources created by this module."
}
