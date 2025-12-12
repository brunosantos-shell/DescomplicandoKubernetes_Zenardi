variable "ami_id" {
  description = "ID da AMI (Ubuntu) a ser usada"
  type        = string
}

variable "instance_type" {
  description = "Tipo da instância (ex: t3.medium)"
  type        = string
  default     = "t3.small"
}

variable "subnet_id" {
  description = "Subnet onde a instância será criada"
  type        = string
}

variable "security_group_ids" {
  description = "Lista de Security Groups"
  type        = list(string)
}

variable "key_name" {
  description = "Nome da chave SSH"
  type        = string
}

variable "node_name" {
  description = "Prefixo do nome da instância (ex: k8s-worker)"
  type        = string
}

variable "instance_count" {
  description = "Quantas instâncias criar"
  type        = number
  default     = 1
}

variable "user_data" {
  description = "Script de inicialização (bash)"
  type        = string
}