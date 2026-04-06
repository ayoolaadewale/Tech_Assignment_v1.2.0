variable "aws_region" {
  description = "AWS region to deploy the cluster into"
  type        = string
  default     = "eu-west-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster (also used to name associated resources)"
  type        = string
  default     = "opsfleet-dedicated-dev-eks-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.35.3"
}

variable "environment" {
  description = "Environment label applied to all resources via default_tags"
  type        = string
  default     = "development"
}

variable "vpc_cidr" {
  description = "CIDR block for the dedicated VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "system_node_instance_types" {
  description = "Instance types for the managed system node group (runs kube-system add-ons)"
  type        = list(string)
  default     = ["m5.large", "m5a.large"]
}

variable "karpenter_version" {
  description = "Helm chart version for Karpenter"
  type        = string
  default     = "1.10.0"
}
