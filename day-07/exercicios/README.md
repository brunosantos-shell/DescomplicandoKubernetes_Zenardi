10 exercícios práticos focados especificamente no módulo **StatefulSets** e os tipos de **Services** (ClusterIP, NodePort, LoadBalancer, ExternalName).

---

### Pré-requisitos

* Um cluster Kubernetes rodando
* Configuração do `kubectl`.

---
---


### Exercício 1: O Par Indissociável (StatefulSet + Headless Service)

**Conceito:** Diferente de Deployments, StatefulSets geralmente exigem um "Headless Service" (sem IP de cluster) para controlar o domínio de rede de cada pod individualmente.
**Tarefa:**

1. Crie um manifesto `web-statefulset.yaml` contendo:
* Um **Service** chamado `nginx-headless`. Defina `clusterIP: None` (isso o torna Headless).
* Um **StatefulSet** chamado `web` com 3 réplicas da imagem `nginx`.
* No StatefulSet, referencie o serviço: `serviceName: "nginx-headless"`.

2. Aplique no cluster.
3. **Verificação:** Liste os pods e note os nomes (`web-0`, `web-1`...). Eles são sequenciais e previsíveis?

---

### Exercício 2: Identidade de Rede Estável (DNS)

**Conceito:** Testar como o DNS resolve cada pod individualmente.
**Tarefa:**

1. Execute um pod temporário com ferramentas de rede:
`kubectl run -it --rm debug --image=busybox:1.28 --restart=Never -- sh`
2. Dentro do pod, faça um `nslookup` no serviço headless:
`nslookup nginx-headless`
3. Faça um `nslookup` em um pod específico:
`nslookup web-0.nginx-headless.default.svc.cluster.local`
**Objetivo:** Entender que cada pod tem seu próprio registro DNS direto, essencial para clusters de Banco de Dados.

---

### Exercício 3: Persistência com VolumeClaimTemplates (AWS EBS)

**Conceito:** Cada réplica precisa de seu próprio disco.
**Tarefa:**

1. Modifique ou crie um novo StatefulSet que inclua a seção `volumeClaimTemplates`.
2. Use a `storageClassName: gp2` (ou a classe criada no módulo anterior).
3. Solicite 1Gi de armazenamento. O ponto de montagem deve ser `/usr/share/nginx/html`.
4. Aplique e verifique se foram criados 3 PVCs distintos (`data-web-0`, `data-web-1`, etc.).
5. Entre no pod `web-0`, crie um arquivo `index.html` com conteúdo único ("Sou o Web-0").
6. Delete o pod `web-0`. Espere ele voltar e verifique se o arquivo ainda está lá.

---

### Exercício 4: Expondo via ClusterIP (Acesso Interno Unificado)

**Conceito:** Às vezes você quer acessar "qualquer" pod do conjunto para leitura, sem se importar com qual.
**Tarefa:**

1. Crie um arquivo `service-clusterip.yaml`.
2. Defina um Service do tipo `ClusterIP` (padrão) chamado `web-public-access`.
3. Aponte o seletor para os pods do StatefulSet `web`.
4. Aplique e verifique o IP com `kubectl get svc`.
5. Tente acessar esse IP (via `curl`) de dentro de outro pod (ex: o pod `debug` do exercício 2). O tráfego deve ser balanceado entre as réplicas.

---

### Exercício 5: Expondo via NodePort (Acesso Externo Simples)

**Conceito:** Abrir uma porta física em cada nó do cluster para acesso externo.
**Tarefa:**

1. Edite o serviço `web-public-access` ou crie um novo.
2. Mude o `type` para `NodePort`.
3. (Opcional) Defina uma `nodePort` fixa entre 30000-32767, exemplo `30050`.
4. Obtenha o IP público de um dos nós EC2 do seu cluster na AWS.
5. No seu navegador ou terminal local, tente acessar `http://<IP-DO-NODE>:30050`.
* *Nota:* Lembre-se de liberar a porta 30050 no **Security Group** dos nodes na AWS, senão o acesso será bloqueado.

---

### Exercício 6: Expondo via LoadBalancer (Integração AWS CLB/NLB)

**Conceito:** O jeito "produção" de expor serviços na nuvem.
**Tarefa:**

1. Crie um manifesto `service-lb.yaml` para o app Nginx.
2. Defina `type: LoadBalancer`.
3. Aplique e monitore com `kubectl get svc -w`. Aguarde o `EXTERNAL-IP` aparecer (na AWS será um DNS longo como `a45...us-east-1.elb.amazonaws.com`).
4. Acesse esse endereço pelo navegador.
5. **Verificação na AWS:** Vá ao console da AWS -> EC2 -> Load Balancers e veja o ELB que o Kubernetes criou automaticamente para você.

---

### Exercício 7: Mapeando Serviços Externos com ExternalName

**Conceito:** Você quer que seu app conecte em `meu-banco-db`, mas o banco real é um RDS da AWS (`rds-banco-xyz.us-east-1...`).
**Tarefa:**

1. Crie um manifesto `service-external.yaml`.
2. Defina:
```yaml
kind: Service
spec:
  type: ExternalName
  externalName: google.com  # Usaremos google para teste simples

```


Chame o serviço de `my-search-engine`.
3. Entre no pod `debug` novamente (`kubectl run ...`).
4. Dê um `nslookup my-search-engine`.
5. **Resultado:** Você verá que o Kubernetes retorna um **CNAME** apontando para `google.com`. Isso abstrai a complexidade do endereço real para dentro do cluster.

---

### Exercício 8: Escalonamento Ordenado (Scaling)

**Conceito:** StatefulSets escalam de forma estrita (0->1->2).
**Tarefa:**

1. Abra dois terminais.
* Terminal 1: `kubectl get pods -w`
* Terminal 2: `kubectl scale statefulset web --replicas=5`


2. Observe a ordem de criação. O `web-4` só nasce quando o `web-3` estiver *Running*?
3. Agora faça o inverso: `kubectl scale statefulset web --replicas=2`.
4. Observe a ordem de terminação. É do maior para o menor?

---

### Exercício 9: Simulando Falha de Nó (Pod Rescheduling)

**Conceito:** Diferente de Deployments, se um Nó morre, o Kubernetes *não* move automaticamente o Pod do StatefulSet a menos que tenha certeza que o antigo morreu (para evitar corrupção de dados com dois pods gravando no mesmo disco).
**Tarefa:**

1. Identifique em qual nó o `web-0` está rodando (`kubectl get pod web-0 -o wide`).
2. (Simulação segura) Delete o Pod forçadamente: `kubectl delete pod web-0 --grace-period=0 --force`.
3. Observe ele sendo recriado. Ele pegou o **mesmo** nome? Ele montou o **mesmo** PVC anterior? (Use `kubectl describe pod web-0` para ver os eventos e volumes montados).

---

### Exercício 10: Limpeza e Orfãos (Retenção de PVCs)

**Conceito:** Deletar um StatefulSet **não** deleta seus discos (PVCs). Isso é uma medida de segurança.
**Tarefa:**

1. Delete o StatefulSet: `kubectl delete statefulset web`.
2. Liste os PVCs: `kubectl get pvc`.
3. **Surpresa:** Os discos ainda estão lá! Isso garante que você não perca dados acidentalmente.
4. **Desafio final:** Crie um script ou comando para limpar tudo (Deletar o Service LoadBalancer, os PVCs órfãos e o StatefulSet).

---
