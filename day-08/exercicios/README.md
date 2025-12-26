# Exercicios

O objetivo é que você execute esses passos em seu terminal (usando Minikube, Kind ou um cluster de teste) para fixar os comandos e a estrutura dos manifestos YAML.

---

### 🟢 Nível Fácil (Aquecimento)

**1. O Detetive do Base64**
Você encontrou uma string perdida nos logs da aplicação: `U2VncmVkb1N1cGVyU2VjcmV0bw==`.

* **Tarefa:** Utilize o comando do Linux no terminal para decodificar essa string e descobrir qual é a senha original.
* **Objetivo:** Praticar o encoding/decoding manual que o Kubernetes faz automaticamente por trás dos panos.

---

**2. O Segredo via Linha de Comando**
Você precisa criar uma credencial de banco de dados rapidamente para um teste.

* **Tarefa:** Sem criar um arquivo YAML, use o comando `kubectl create secret` para criar um Secret do tipo `generic` chamado `db-access`. Ele deve conter dois dados: `db_host=localhost` e `db_pass=batata123`.
* **Validação:** Rode um `kubectl get secret db-access -o yaml` e verifique se os valores estão codificados.

---

**3. Injeção de Variáveis (ConfigMap)**
Uma aplicação precisa saber a cor do tema da interface, mas isso não é um dado sensível.

* **Tarefa:** Crie um ConfigMap chamado `app-colors` contendo a chave `primary_color` com valor `blue`. Em seguida, crie um Pod simples (imagem `nginx`) que tenha uma variável de ambiente chamada `THEME_COLOR` que recebe o valor diretamente desse ConfigMap.

---

**4. O Pod "Espião"**
Você quer garantir que o Kubernetes está injetando os segredos corretamente.

* **Tarefa:** Crie um Secret chamado `api-key` com o valor `key=12345`. Crie um Pod usando a imagem `busybox` com o comando `sleep 3600`. Injete esse secret como variável de ambiente.
* **Validação:** Entre no pod (`kubectl exec`) e rode o comando `env` para ver se a variável aparece lá.

**5. Configuração via Arquivo**
Você tem um arquivo local chamado `index.html` com o conteúdo 
```html
<h1>Ola Kubernetes</h1>
```

* **Tarefa:** Crie um ConfigMap chamado `site-html` utilizando o parâmetro `--from-file` apontando para este arquivo.
* **Objetivo:** Entender como transformar arquivos físicos locais em objetos do Kubernetes rapidamente.

---
---

### 🔴 Nível Desafiador (Expert Mode)

**6. Credenciais do Docker Hub (Private Registry)**
Você precisa baixar uma imagem de um repositório privado, mas o Kubernetes não tem permissão.

**Tarefa:**
  1. Gere a string Base64 do seu arquivo `~/.docker/config.json` (ou crie um fictício).
  2. Crie um manifesto YAML para um Secret do tipo `kubernetes.io/dockerconfigjson` chamado `my-registry-key`.
  3. Crie um manifesto de Pod que utilize o campo `imagePullSecrets` referenciando este segredo.

---

**7. Servidor Web Seguro (TLS Manual)**
Vamos simular a proteção de um endpoint.

**Tarefa:**
1. Gere um certificado auto-assinado e uma chave privada usando `openssl` (como visto na aula).
2. Crie um Secret do tipo `kubernetes.io/tls` chamado `meu-site-tls`.
3. Crie um Pod Nginx que monte esse secret no caminho `/etc/nginx/tls`.
4. Entre no container e verifique se os arquivos `tls.crt` e `tls.key` estão no diretório montado.

---

**8. O Combo Completo (ConfigMap + Secret + Volume Mount)**
Cenário real de aplicação: Configuração + Senha.

**Tarefa:** Crie um Pod `webapp` que:
1. Use um **ConfigMap** montado como **Volume** em `/app/config` contendo um arquivo `settings.ini`.
2. Use um **Secret** injetado como **Variável de Ambiente** (`DB_PASSWORD`).
*Dica:* Lembre-se que `volumeMounts` e `env` são campos irmãos dentro de `containers`.

---

**9. Imutabilidade e Atualização**
Você quer proteger a configuração de produção contra mudanças acidentais.

* **Tarefa:** Crie um ConfigMap chamado `prod-config` com a propriedade `immutable: true`. Tente aplicar uma alteração nesse ConfigMap (mude um valor e rode `kubectl apply`). Observe o erro gerado pelo Kubernetes.
* **Objetivo:** Entender na prática a restrição de edição de recursos imutáveis.

---

**10. Substituição Cirúrgica com `subPath**`**
O container do Nginx já tem vários arquivos em `/etc/nginx/`. Se você montar um volume nesse diretório, todos os arquivos originais sumirão, sobrando apenas o seu.

* **Tarefa:** Crie um ConfigMap com um arquivo `nginx.conf` customizado. Monte esse arquivo no Pod do Nginx de forma que ele substitua **apenas** o arquivo `/etc/nginx/nginx.conf`, mantendo os outros arquivos originais (como `mime.types`) intactos no diretório.
* *Dica:* Pesquise ou revise como usar a propriedade `subPath` no `volumeMounts` para montar um único arquivo ao invés do diretório todo.


