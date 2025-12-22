
---

### Solução Exercício 1: O Par Indissociável (StatefulSet + Headless Service)

Aqui criamos o Serviço "sem cabeça" (Headless) que serve para controlar o domínio de rede, e o StatefulSet básico.

**Arquivo:** `ex1-headless-sts.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-headless
  labels:
    app: nginx
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None  # <--- Isso torna o serviço Headless
  selector:
    app: nginx
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  selector:
    matchLabels:
      app: nginx
  serviceName: "nginx-headless" # <--- Conecta ao serviço acima
  replicas: 3
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
          name: web

```

**Comandos:**

```bash
kubectl apply -f ex1-headless-sts.yaml
kubectl get pods
# Resultado esperado: web-0, web-1, web-2 (nomes fixos)

```

---

### Solução Exercício 2: Identidade de Rede Estável (DNS)

Verificando se o DNS resolve para os IPs dos Pods individuais.

**Comandos:**

```bash
# 1. Criar um pod temporário com ferramentas de rede
kubectl run -it --rm debug --image=busybox:1.28 --restart=Never -- sh

# 2. Dentro do pod (o prompt vai mudar para / #), digite:
nslookup nginx-headless
# Deve retornar os 3 IPs dos pods.

# 3. Testar a identidade única:
nslookup web-0.nginx-headless.default.svc.cluster.local
# Deve retornar apenas o IP do pod web-0.

# 4. Sair do pod
exit

```

---

### Solução Exercício 3: Persistência com VolumeClaimTemplates

Agora atualizamos o StatefulSet para incluir discos persistentes (EBS na AWS).
*Nota: Se você não tiver uma StorageClass padrão definida, adicione `storageClassName: gp2` (ou a classe criada no módulo anterior) dentro do template.*

**Arquivo:** `ex3-sts-pvc.yaml`

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  selector:
    matchLabels:
      app: nginx
  serviceName: "nginx-headless"
  replicas: 3
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
          name: web
        volumeMounts:        # <--- Onde montar no container
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:      # <--- A mágica acontece aqui
  - metadata:
      name: www
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 1Gi
      # storageClassName: gp2  <-- Descomente se necessário

```

**Comandos:**

```bash
kubectl apply -f ex3-sts-pvc.yaml

# Verificar se criou os PVCs
kubectl get pvc
# Resultado esperado: www-web-0, www-web-1, www-web-2

# Teste de persistência:
kubectl exec web-0 -- sh -c 'echo "Sou o Web-0" > /usr/share/nginx/html/index.html'
kubectl delete pod web-0
# Aguarde recriar e verifique:
kubectl exec web-0 -- cat /usr/share/nginx/html/index.html

```

---

### Solução Exercício 4: Expondo via ClusterIP

Criando um IP virtual único para balancear a carga internamente.

**Arquivo:** `ex4-clusterip.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-public-access
spec:
  type: ClusterIP  # Padrão, mas explícito para didática
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80

```

**Comandos:**

```bash
kubectl apply -f ex4-clusterip.yaml
kubectl get svc web-public-access
# Copie o CLUSTER-IP gerado e teste de dentro do pod debug (Ex 2) com curl <IP>

```

---

### Solução Exercício 5: Expondo via NodePort

Expondo em uma porta física dos nós EC2.

**Arquivo:** `ex5-nodeport.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-public-access  # Reutilizando o nome para atualizar o anterior
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
      nodePort: 30050  # Porta fixa

```

**Comandos:**

```bash
kubectl apply -f ex5-nodeport.yaml

```

**Atenção na AWS:** Para que isso funcione no seu navegador, você deve ir ao Console da AWS > EC2 > Security Group do seu Node > Edit Inbound Rules > Adicionar regra TCP porta 30050 para `0.0.0.0/0`.
Depois acesse: `http://<IP-Publico-do-Node>:30050`

---

### Solução Exercício 6: Expondo via LoadBalancer

A forma correta de expor na nuvem.

**Arquivo:** `ex6-loadbalancer.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-lb
spec:
  type: LoadBalancer
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80

```

**Comandos:**

```bash
kubectl apply -f ex6-loadbalancer.yaml
kubectl get svc web-lb -w

```

*Espere alguns minutos até que `<pending>` mude para um endereço longo (ex: `a43...us-east-1.elb.amazonaws.com`). Copie e cole no navegador.*

---

### Solução Exercício 7: ExternalName

Mapeando um nome externo para dentro do cluster.

**Arquivo:** `ex7-externalname.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-search-engine
spec:
  type: ExternalName
  externalName: google.com

```

**Comandos:**

```bash
kubectl apply -f ex7-externalname.yaml

# Teste:
kubectl run -it --rm debug --image=busybox:1.28 --restart=Never -- nslookup my-search-engine
# Resultado: Você verá o Canonical Name apontando para google.com

```

---

### Solução Exercício 8: Escalonamento Ordenado

Observando a ordem estrita.

**Comandos:**

```bash
# Terminal 1 (Monitoramento)
kubectl get pods -w

# Terminal 2 (Ação)
kubectl scale statefulset web --replicas=5

```

**Observação:** Você verá `web-3` sendo criado. Somente quando `web-3` estiver **Running**, o `web-4` começará a ser criado. Ao diminuir (`--replicas=2`), ele apaga o `web-4`, espera terminar totalmente, e só depois apaga o `web-3`.

---

### Solução Exercício 9: Simulando Falha (Rescheduling)

**Comandos:**

```bash
# Deletar forçado para simular falha abrupta
kubectl delete pod web-0 --grace-period=0 --force

# Listar rapidamente
kubectl get pods -w

```

**Observação:** O Kubernetes cria um novo pod imediatamente chamado, adivinhe? **`web-0`**. Ele não cria `web-5` ou um nome aleatório. Ele restaura a identidade perdida e remonta o disco `www-web-0`.

---

### Solução Exercício 10: Limpeza e Orfãos

Demonstrando que os dados sobrevivem ao objeto lógico.

**Comandos:**

```bash
# 1. Deletar o StatefulSet
kubectl delete statefulset web

# 2. Verificar que os pods morrem, mas os discos ficam
kubectl get pvc
# Os PVCs www-web-0, www-web-1, etc. continuam lá!

# 3. Limpeza total (Cuidado: apaga os dados)
kubectl delete svc nginx-headless web-public-access web-lb my-search-engine
kubectl delete pvc -l app=nginx 

```