# Desafios 

---

### Exercício 1: Criando uma StorageClass para AWS EBS (gp3)

**Cenário:** O cluster padrão pode vir com uma classe de armazenamento `gp2`, mas você quer garantir performance e custos otimizados usando volumes do tipo `gp3` (General Purpose SSD de nova geração).

**Tarefa:**

1. Crie um manifesto YAML para uma nova `StorageClass` chamada `aws-sc-fast`.
2. O provisioner deve ser o driver CSI da AWS (`ebs.csi.aws.com`) ou o in-tree (`kubernetes.io/aws-ebs`), dependendo da versão do seu cluster (prefira o CSI se estiver no EKS recente).
3. Defina o parâmetro de tipo como `gp3`.
4. Garanta que a política de *Reclaim* seja `Delete` e que o modo de *Binding* seja `WaitForFirstConsumer` (para garantir que o volume seja criado na mesma zona de disponibilidade do Pod).

**Objetivo:** Entender como definir classes de armazenamento personalizadas e parâmetros específicos da nuvem.

---

### Exercício 2: Provisionamento Dinâmico (Dynamic Provisioning) com PVC

**Cenário:** Uma aplicação web precisa de 5Gi de armazenamento persistente.

**Tarefa:**

1. Crie um arquivo YAML para um `PersistentVolumeClaim` chamado `web-pvc`.
2. Solicite **5Gi** de armazenamento.
3. Aponte para a `StorageClass` criada no Exercício 1 (`aws-sc-fast`) usando a anotação ou campo `storageClassName`.
4. Aplique o YAML no cluster.
5. **Verificação:** Execute `kubectl get pvc` e `kubectl get pv`.
* *Dica:* Se você usou `WaitForFirstConsumer` no exercício anterior, o status do PVC ficará como `Pending` até que um Pod tente usá-lo. Isso é esperado!



**Objetivo:** Praticar a criação de solicitações de volume e entender o comportamento do provisionamento dinâmico.

---

### Exercício 3: Consumindo o Volume em um Pod

**Cenário:** Você precisa subir um servidor Nginx que utilize o volume solicitado para salvar seus logs ou arquivos HTML.

**Tarefa:**

1. Crie um Pod chamado `nginx-storage-pod`.
2. Use a imagem `nginx:latest`.
3. Monte o PVC `web-pvc` (do Exercício 2) no caminho `/usr/share/nginx/html`.
4. Aplique o manifesto.
5. **Ação:** Entre no pod (`kubectl exec -it nginx-storage-pod -- /bin/bash`) e crie um arquivo dentro de `/usr/share/nginx/html/index.html` com o texto "Olá Kubernetes Storage".
6. Delete o Pod e recrie-o. Verifique se o arquivo ainda existe.

**Objetivo:** Entender como montar volumes em containers e verificar a persistência dos dados além do ciclo de vida do Pod.

---

### Exercício 4: Alterando a Política de Retenção (Reclaim Policy)

**Cenário:** Por padrão, quando você deleta um PVC provisionado dinamicamente, o volume na AWS (EBS) também é deletado (devido à política `Delete`). Porém, para dados críticos, você quer evitar a perda acidental.

**Tarefa:**

1. Identifique o nome do **PersistentVolume (PV)** que foi criado automaticamente para o seu `web-pvc` (use `kubectl get pv`).
2. Edite esse PV (`kubectl edit pv <nome-do-pv>`) e altere a `persistentVolumeReclaimPolicy` de `Delete` para `Retain`.
3. Delete o **PVC** (`kubectl delete pvc web-pvc`). O Pod deve ser deletado antes ou o PVC ficará preso em "Terminating".
4. Verifique o status do PV. Ele deve estar como `Released` (ou `Available` dependendo da versão/config), mas o volume EBS na AWS **não** deve ser excluído.

**Objetivo:** Aprender a proteger dados alterando políticas de retenção e entender a diferença entre deletar um objeto Kubernetes e o recurso físico na nuvem.

---

### Exercício 5: Expandindo um Volume (Resizing)

**Cenário:** O espaço de 5Gi ficou pequeno e a aplicação precisa de 10Gi.

**Tarefa:**

1. Primeiro, certifique-se que sua `StorageClass` (do Exercício 1) possui a flag `allowVolumeExpansion: true`. Se não tiver, edite-a para adicionar.
2. Recrie o PVC `web-pvc` (se você o deletou no ex 4, terá que refazer o processo de ligação ou criar um novo e apontar para um novo Pod). Vamos assumir um PVC ativo e ligado a um PV.
3. Edite o PVC e altere o campo `resources.requests.storage` de `5Gi` para `10Gi`.
4. Aplique a alteração.
5. Verifique se o tamanho foi atualizado (pode ser necessário reiniciar o Pod ou aguardar o driver CSI processar a mudança no sistema de arquivos).

**Objetivo:** Praticar a redimensionamento de volumes, uma tarefa comum de "Dia 2" na operação de clusters.