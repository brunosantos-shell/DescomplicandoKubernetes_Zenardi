output "ssh_command_control_plane" {
  value = "ssh -i k8s-key.pem ubuntu@${module.control_plane.public_ips[0]}"
}

output "worker_ips" {
  value = module.workers.public_ips
}