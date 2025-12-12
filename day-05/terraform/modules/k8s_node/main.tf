resource "aws_instance" "node" {
  count         = var.instance_count
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  key_name      = var.key_name
  
  vpc_security_group_ids = var.security_group_ids

  # Script de instalação injetado aqui
  user_data = var.user_data

  tags = {
    # Se for count 1, o nome fica "k8s-control-plane-0"
    Name = "${var.node_name}-${count.index}" 
  }
}