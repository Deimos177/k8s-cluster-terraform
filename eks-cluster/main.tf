variable "region" {
  type      = string
  sensitive = true
}
variable "cluster_service_role" {
  type      = string
  sensitive = true
}
variable "principal_arn" {
  type      = string
  sensitive = true
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.39.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.2"

  name = "eks-study-vpc"
  cidr = "10.0.0.0/16"

  azs             = data.aws_availability_zones.available.names
  private_subnets = ["10.0.0.0/22", "10.0.4.0/22", "10.0.8.0/22"]
  public_subnets  = ["10.0.100.0/22", "10.0.104.0/22", "10.0.108.0/22"]

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_vpn_gateway = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    Name = "VPC Public Subnets"
  }
  private_subnet_tags = {
    Name = "VPC private Subnets"
  }
  database_subnet_tags = {
    Name = "VPC Private Database Subnets"
  }

  map_public_ip_on_launch = true
}

locals {
  vpc_id              = module.vpc.vpc_id
  vpc_cidr            = module.vpc.vpc_cidr_block
  public_subnets_ids  = module.vpc.public_subnets
  private_subnets_ids = module.vpc.private_subnets
  subnets_ids         = module.vpc.intra_subnets
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.4.0"

  cluster_name    = "study-cluster"
  cluster_version = "1.29"

  cluster_endpoint_public_access = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  vpc_id                   = local.vpc_id
  subnet_ids               = local.private_subnets_ids
  control_plane_subnet_ids = local.subnets_ids

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = ["t3.medium"]

    iam_cluster_primary_security_group = true
    iam_role_attach_cni_policy         = true
  }

  eks_managed_node_groups = {
    study-cluster-wg = {
      min_size     = 2
      max_size     = 5
      desired_size = 2

      instance_types = ["t3.medium"]
      capacity_type  = "SPOT"
      tags = {
        Environment = "Study"
      }
    }
  }

  enable_cluster_creator_admin_permissions = true
}

module "vpc_cni_irsa" {
  depends_on = [module.eks]
  source     = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version    = "~> 5.0"

  role_name_prefix      = "VPC-CNI-IRSA"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
}