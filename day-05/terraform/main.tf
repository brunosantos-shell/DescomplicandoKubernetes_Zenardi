# ==========================================
# 1. REDE E SEGURANÇA (Base Infrastructure)
# ==========================================

resource "aws_vpc" "k8s_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "k8s-vpc" }
}

resource "aws_internet_gateway" "k8s_igw" {
  vpc_id = aws_vpc.k8s_vpc.id
  tags   = { Name = "k8s-igw" }
}

resource "aws_subnet" "k8s_subnet" {
  vpc_id                  = aws_vpc.k8s_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags                    = { Name = "k8s-subnet" }
}

resource "aws_route_table" "k8s_rt" {
  vpc_id = aws_vpc.k8s_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k8s_igw.id
  }
}

resource "aws_route_table_association" "k8s_rta" {
  subnet_id      = aws_subnet.k8s_subnet.id
  route_table_id = aws_route_table.k8s_rt.id
}

resource "aws_security_group" "k8s_sg" {
  name        = "k8s-sg"
  description = "Kubernetes Security Group"
  vpc_id      = aws_vpc.k8s_vpc.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # API Server
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Comunicação interna total (Necessário para Cilium/K8s)
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==========================================
# 2. CHAVES SSH
# ==========================================

resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "k8s_key" {
  key_name   = "k8s-key-module"
  public_key = tls_private_key.pk.public_key_openssh
}

resource "local_file" "ssh_key" {
  filename        = "${path.module}/k8s-key.pem"
  content         = tls_private_key.pk.private_key_pem
  file_permission = "0400"
}

# ==========================================
# 3. INSTÂNCIAS (Usando o Módulo)
# ==========================================

# Busca a AMI do Ubuntu
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

module "control_plane" {
  source = "./modules/k8s_node"
  node_name          = "k8s-control-plane"
  instance_count     = 1
  instance_type      = "t3.medium"
  ami_id             = data.aws_ami.ubuntu.id
  subnet_id          = aws_subnet.k8s_subnet.id
  security_group_ids = [aws_security_group.k8s_sg.id]
  key_name           = aws_key_pair.k8s_key.key_name
  user_data          = "" # Vazio, o Ansible fará o trabalho
}

module "workers" {
  source = "./modules/k8s_node"
  node_name          = "k8s-worker"
  instance_count     = 2
  instance_type      = "t3.small"
  ami_id             = data.aws_ami.ubuntu.id
  subnet_id          = aws_subnet.k8s_subnet.id
  security_group_ids = [aws_security_group.k8s_sg.id]
  key_name           = aws_key_pair.k8s_key.key_name
  user_data          = "" # Vazio
}

# --- GERAÇÃO DO INVENTÁRIO ANSIBLE ---
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tpl", {
    control_plane_ip = module.control_plane.public_ips[0]
    worker_ips       = module.workers.public_ips
    ssh_key_path     =abspath("${path.module}/k8s-key.pem")
  })
  filename = "${path.module}/ansible/inventory.ini"
}