


# Crie a Infra (Terraform):

```bash
terraform init
terraform apply -auto-approve
```

Isso cria as VMs e gera automaticamente o arquivo ansible/inventory.ini.

Configure o Software (Ansible): Aguarde uns 2 minutos para garantir que o SSH das máquinas subiu completamente na AWS.

```bash
cd ansible

# Executa o playbook principal
ansible-playbook -i inventory.ini site.yml
```

Quando o Ansible terminar, você pode acessar o control plane:

```bash
ssh -i ../k8s-key.pem ubuntu@<IP_DO_CONTROL_PLANE>
kubectl get nodes
cilium status
```

# Referencias
Testar com diferentes plugins de rede
- https://github.com/projectcalico/calico
- https://github.com/flannel-io/flannel
- https://github.com/cilium/cilium
- https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/