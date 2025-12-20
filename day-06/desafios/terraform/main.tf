terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

locals {
  cluster_name = "k8s-linuxtips-lab"
}

# ---------------------------------------------------------------------------
# 1. VPC (Rede)
# ---------------------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "k8s-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true 
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = {
    "OWNER" = "ZEE8CA"
    "DateToDelete": "Today"
  }
}

# ---------------------------------------------------------------------------
# 2. EKS Cluster & EBS CSI Driver
# ---------------------------------------------------------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0" # Atualizado para v20 para compatibilidade com AWS Provider v5

  cluster_name    = local.cluster_name
  cluster_version = "1.29"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  # Garante que quem roda o terraform seja admin do cluster
  enable_cluster_creator_admin_permissions = true

  # Habilita OIDC para podermos usar Roles de IAM nos Pods
  enable_irsa = true

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
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.irsa_ebs_csi.iam_role_arn
    }
  }

  eks_managed_node_groups = {
    main = {
      min_size     = 2
      max_size     = 3
      desired_size = 2

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      
      # Segurança para nós acessarem EFS
      vpc_security_group_ids = [aws_security_group.node_efs_access.id]
      
      # Necessário para evitar erros de disco na v20 em alguns casos
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 125
            encrypted             = true
            delete_on_termination = true
          }
        }
      }
    }
  }

  tags = {
    "OWNER" = "ZEE8CA"
    "DateToDelete": "Today"
  }
}

# ---------------------------------------------------------------------------
# 3. Permissões IAM para o EBS CSI Driver (IRSA)
# ---------------------------------------------------------------------------
module "irsa_ebs_csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.30"

  role_name             = "ebs-csi-role-${local.cluster_name}"
  attach_ebs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

# ---------------------------------------------------------------------------
# 4. KMS Key (Para o Exercício Avançado 5 - Criptografia)
# ---------------------------------------------------------------------------
resource "aws_kms_key" "k8s_lab_key" {
  description             = "Chave KMS para exercicios de Kubernetes Storage"
  deletion_window_in_days = 7
  tags = {
    "OWNER" = "ZEE8CA"
    "DateToDelete": "Today"
  }
}

resource "aws_kms_alias" "k8s_lab_key_alias" {
  name          = "alias/k8s-lab-storage"
  target_key_id = aws_kms_key.k8s_lab_key.key_id
}

# ---------------------------------------------------------------------------
# 5. Infraestrutura EFS (Para o Exercício Avançado 4 - ReadWriteMany)
# ---------------------------------------------------------------------------

resource "aws_security_group" "node_efs_access" {
  name        = "k8s-node-efs-access"
  description = "Permite acesso NFS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "NFS from VPC"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "OWNER" = "ZEE8CA"
    "DateToDelete": "Today"
  }
}

resource "aws_efs_file_system" "k8s_efs" {
  creation_token = "k8s-lab-efs"
  encrypted      = true

  tags = {
    "OWNER" = "ZEE8CA"
    "DateToDelete": "Today"
     Name = "k8s-lab-efs"
  }
}

resource "aws_efs_mount_target" "zone_a" {
  file_system_id  = aws_efs_file_system.k8s_efs.id
  subnet_id       = module.vpc.private_subnets[0]
  security_groups = [aws_security_group.node_efs_access.id]
}

resource "aws_efs_mount_target" "zone_b" {
  file_system_id  = aws_efs_file_system.k8s_efs.id
  subnet_id       = module.vpc.private_subnets[1]
  security_groups = [aws_security_group.node_efs_access.id]
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------
output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  description = "Comando para configurar o kubectl"
  value       = "aws eks --region us-east-1 update-kubeconfig --name ${local.cluster_name}"
}

output "kms_key_arn" {
  description = "ARN da chave KMS para o Exercicio 5"
  value       = aws_kms_key.k8s_lab_key.arn
}

output "efs_id" {
  description = "ID do File System EFS para o Exercicio 4"
  value       = aws_efs_file_system.k8s_efs.id
}