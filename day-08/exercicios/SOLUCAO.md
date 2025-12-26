
---

# 🟢 Nível Fácil (Aquecimento)

### 1. O Detetive do Base64

**Solução:**
Abra o terminal e execute:

```bash
echo -n 'U2VncmVkb1N1cGVyU2VjcmV0bw==' | base64 -d

```

**Resultado:** A senha secreta é `SegredoSuperSecreto`.
*Nota: O `-n` no echo é importante para não adicionar uma quebra de linha extra que pode corromper o base64.*

---

### 2. O Segredo via Linha de Comando

**Solução:**

```bash
# Cria o secret
kubectl create secret generic db-access --from-literal=db_host=localhost --from-literal=db_pass=batata123

# Validação (você verá os valores codificados em base64)
kubectl get secret db-access -o yaml

```

---

### 3. Injeção de Variáveis (ConfigMap)

**Manifesto `ex3-colors.yaml`:**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-colors
data:
  primary_color: blue
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-colors
spec:
  containers:
  - name: nginx
    image: nginx
    env:
    - name: THEME_COLOR
      valueFrom:
        configMapKeyRef:
          name: app-colors
          key: primary_color

```

**Comando:** `kubectl apply -f ex3-colors.yaml`

---

### 4. O Pod "Espião"

**Passo 1: Gerar o Base64**
`echo -n '12345' | base64` (Resultado: `MTIzNDU=`)

**Manifesto `ex4-spy.yaml`:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: api-key
type: Opaque
data:
  key: MTIzNDU=
---
apiVersion: v1
kind: Pod
metadata:
  name: spy-pod
spec:
  containers:
  - name: busybox
    image: busybox
    command: ["sleep", "3600"]
    env:
    - name: MY_API_KEY
      valueFrom:
        secretKeyRef:
          name: api-key
          key: key

```

**Validação:**

```bash
kubectl apply -f ex4-spy.yaml
kubectl exec spy-pod -- env | grep MY_API_KEY
# Deve retornar: MY_API_KEY=12345

```

---

### 5. Configuração via Arquivo

**Solução:**

1. Crie o arquivo: `echo "<h1>Ola Kubernetes</h1>" > index.html`
2. Crie o ConfigMap:

```bash
kubectl create configmap site-html --from-file=index.html

```

3. Verifique: `kubectl describe configmap site-html`

---

# 🔴 Nível Desafiador (Expert Mode)

### 6. Credenciais do Docker Hub

**Manifesto `ex6-docker.yaml`:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-registry-key
type: kubernetes.io/dockerconfigjson
data:
  # Coloque aqui o output do comando: base64 ~/.docker/config.json
  .dockerconfigjson: ewoJImF1dGhzIjogewoJCSJodHRwczovL2luZGV4LmRvY2tlci5pby92MS8iOiB7CgkJCSJhdXRoIjogInVzZXJuYW1lOnBhc3N3b3JkIgoJCX0KCX0KfQ==
---
apiVersion: v1
kind: Pod
metadata:
  name: private-pod
spec:
  imagePullSecrets:
  - name: my-registry-key
  containers:
  - name: app
    image: meu-usuario/minha-imagem-privada:v1

```

---

### 7. Servidor Web Seguro (TLS Manual)

**Passo 1: Gerar chaves**

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=meusite.com"

```

**Manifesto `ex7-tls.yaml`:**
(Nota: Para facilitar, vou usar o comando imperativo para criar o segredo, mas o manifesto do Pod é obrigatório).

```bash
# Cria o secret
kubectl create secret tls meu-site-tls --cert=tls.crt --key=tls.key

```

**Manifesto do Pod:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-tls
spec:
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - name: tls-vol
      mountPath: "/etc/nginx/tls"
      readOnly: true
  volumes:
  - name: tls-vol
    secret:
      secretName: meu-site-tls

```

**Validação:** `kubectl exec nginx-tls -- ls /etc/nginx/tls`

---

### 8. O Combo Completo

**Manifesto `ex8-combo.yaml`:**

```yaml
# 1. ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-settings
data:
  settings.ini: |
    [General]
    debug=true
---
# 2. Secret
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
stringData: # Dica: stringData dispensa o uso de base64 manual no YAML!
  password: "SenhaSuperDificil"
---
# 3. Pod
apiVersion: v1
kind: Pod
metadata:
  name: webapp
spec:
  containers:
  - name: app
    image: nginx
    # Injeção via Env (Secret)
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: password
    # Injeção via Volume (ConfigMap)
    volumeMounts:
    - name: config-vol
      mountPath: /app/config
  volumes:
  - name: config-vol
    configMap:
      name: app-settings

```

---

### 9. Imutabilidade e Atualização

**Manifesto `ex9-immutable.yaml`:**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prod-config
data:
  env: "production"
immutable: true

```

**Teste:**

1. Aplique: `kubectl apply -f ex9-immutable.yaml`
2. Mude `env: "production"` para `env: "dev"` no arquivo.
3. Aplique de novo.
**Resultado:** O Kubernetes retornará um erro: `Forbidden: updates to immutable configmaps are forbidden`.

---

### 10. Substituição Cirúrgica com `subPath`

Este é o exercício mais técnico. Se você não usar `subPath`, a pasta `/etc/nginx` inteira será substituída pelo seu arquivo, apagando arquivos essenciais do Nginx (como `mime.types`), fazendo o Pod falhar.

**Manifesto `ex10-subpath.yaml`:**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-custom-conf
data:
  nginx.conf: |
    events {}
    http {
      server {
        listen 80;
        location / { return 200 "Ola do subPath!"; }
      }
    }
---
apiVersion: v1
kind: Pod
metadata:
  name: nginx-subpath
spec:
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - name: conf-vol
      mountPath: /etc/nginx/nginx.conf # O destino final (incluindo o nome do arquivo)
      subPath: nginx.conf              # A chave exata dentro do ConfigMap
  volumes:
  - name: conf-vol
    configMap:
      name: nginx-custom-conf

```

**Explicação:** O `subPath` diz ao Kubernetes: "Não monte o volume inteiro em cima da pasta. Pegue apenas o arquivo `nginx.conf` de dentro do volume e coloque ele no caminho especificado".