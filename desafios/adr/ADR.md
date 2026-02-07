# Proposta de **Architecture Decision Record (ADR)** formal, estruturada para responder à RFP do KubeBank, com base nas melhores práticas

- [Proposta de **Architecture Decision Record (ADR)** formal, estruturada para responder à RFP do KubeBank, com base nas melhores práticas](#proposta-de-architecture-decision-record-adr-formal-estruturada-para-responder-à-rfp-do-kubebank-com-base-nas-melhores-práticas)
- [ADR-001: Definição de Arquitetura de Segurança, Acesso e Observabilidade - CashFlow API](#adr-001-definição-de-arquitetura-de-segurança-acesso-e-observabilidade---cashflow-api)
  - [1. Decisão: Segurança da Cadeia de Suprimentos (Supply Chain)](#1-decisão-segurança-da-cadeia-de-suprimentos-supply-chain)
    - [1.1. Imagem Base do Container](#11-imagem-base-do-container)
    - [1.2. Scan de Vulnerabilidades no CI/CD](#12-scan-de-vulnerabilidades-no-cicd)
    - [1.3. Assinatura e Integridade de Imagem](#13-assinatura-e-integridade-de-imagem)
  - [2. Decisão: Estratégia de Acesso (Ingress \& TLS)](#2-decisão-estratégia-de-acesso-ingress--tls)
    - [2.1. Exposição do Serviço](#21-exposição-do-serviço)
    - [2.2. Gerenciamento de Certificados (TLS)](#22-gerenciamento-de-certificados-tls)
    - [2.3. Objeto de Roteamento](#23-objeto-de-roteamento)
  - [3. Decisão: Observabilidade Total](#3-decisão-observabilidade-total)
    - [3.1. Descoberta de Métricas (Service Discovery)](#31-descoberta-de-métricas-service-discovery)
    - [3.2. Alerting](#32-alerting)
  - [4. Decisão: Resiliência e Disponibilidade](#4-decisão-resiliência-e-disponibilidade)
    - [4.1. Gerenciamento de Memória (OOMKill)](#41-gerenciamento-de-memória-oomkill)
    - [4.2. Probes (Health Checks)](#42-probes-health-checks)
    - [Resumo Técnico da Implementação](#resumo-técnico-da-implementação)


---

# ADR-001: Definição de Arquitetura de Segurança, Acesso e Observabilidade - CashFlow API

* **Status:** Proposto

* **Data:** 07 de Fevereiro de 2026

* **Contexto:** O projeto KubeBank necessita definir a arquitetura para a aplicação crítica `CashFlow API`. O foco é garantir a segurança da cadeia de suprimentos (Supply Chain Security), estabelecer uma estratégia robusta de Ingress com TLS, integrar com a stack de observabilidade existente (Prometheus) e garantir alta disponibilidade e resiliência dos Pods.

---

## 1. Decisão: Segurança da Cadeia de Suprimentos (Supply Chain)

### 1.1. Imagem Base do Container

**Decisão:** Utilizar imagens **Distroless** (Google) ou **Wolfi** (Chainguard).

**Justificativa:**

* A imagem `ubuntu:latest` contém um sistema operacional completo, incluindo gerenciadores de pacotes (apt), shells e binários desnecessários para a execução da aplicação, o que aumenta drasticamente a superfície de ataque e o número de CVEs (Vulnerabilidades e Exposições Comuns).
* Imagens **Distroless** ou **Wolfi** contêm apenas a aplicação e suas dependências de runtime (ex: JRE, Python, Go libs). Elas não possuem shell (`/bin/sh`), impedindo que atacantes executem comandos arbitrários caso consigam explorar a aplicação. Isso atende ao requisito de "reduzir a superfície de ataque ao máximo".

### 1.2. Scan de Vulnerabilidades no CI/CD

**Decisão:** Implementar o **Trivy** (Aqua Security) no pipeline.

**Justificativa:**

* O Trivy é uma ferramenta abrangente que escaneia tanto vulnerabilidades no sistema operacional (OS packages) quanto dependências da aplicação (npm, pip, maven, go.mod).
* Ele deve ser configurado como um "Quality Gate" no pipeline: se vulnerabilidades de nível CRITICAL ou HIGH forem encontradas, o build deve falhar, impedindo o deploy.

### 1.3. Assinatura e Integridade de Imagem

**Decisão:** Utilizar **Cosign** (parte do projeto Sigstore).

**Justificativa:**

* O Cosign permite assinar a imagem do container no momento do build (push) no registry.
* No cluster Kubernetes, podemos usar um Admission Controller (como Kyverno ou OPA Gatekeeper) para verificar essa assinatura antes de permitir a criação do Pod. Isso garante que apenas imagens geradas e aprovadas pelo pipeline oficial do KubeBank sejam executadas.

---

## 2. Decisão: Estratégia de Acesso (Ingress & TLS)

### 2.1. Exposição do Serviço

**Decisão:** Utilizar um **Ingress Controller** (NGINX).
**Justificativa:**

* Utilizar um `Service` do tipo `LoadBalancer` para cada microserviço é custoso (um IP/LB por serviço) e difícil de gerenciar.
* O **Ingress** atua como um roteador de borda inteligente, permitindo roteamento baseado em host (`api.kubebank.com`) e path (`/cashflow`).
* O **NGINX Ingress Controller** é o padrão de mercado, estável e altamente performático para tráfego HTTP/HTTPS.

### 2.2. Gerenciamento de Certificados (TLS)

**Decisão:** Utilizar **Cert-Manager** com **Let's Encrypt**.
**Justificativa:**

* O Banco Central exige criptografia em trânsito. Gerenciar certificados manualmente é propenso a erros e expiração.
* O **Cert-Manager** é um operador nativo de Kubernetes que automatiza a emissão e renovação de certificados.
* Configuraremos um `ClusterIssuer` (Let's Encrypt Production) para emitir certificados válidos automaticamente ao detectarmos uma anotação de TLS no recurso de Ingress.

### 2.3. Objeto de Roteamento

**Decisão:** Recurso **Ingress**.
**Justificativa:**

* O manifesto `Ingress` é onde definimos as regras: "Todo tráfego chegando em `api.kubebank.com/v1/cashflow` deve ser enviado para o Service `cashflow-api` na porta 8080".

---

## 3. Decisão: Observabilidade Total

### 3.1. Descoberta de Métricas (Service Discovery)

**Decisão:** Criar um manifesto **ServiceMonitor**.
**Justificativa:**

* Como a equipe de Ops já utiliza o `Kube-Prometheus-Stack` (baseado no Prometheus Operator), a forma padrão de configurar o scrape é via CRDs (Custom Resource Definitions).
* O **ServiceMonitor** instrui o Prometheus a monitorar um conjunto de Services Kubernetes (selecionados via `labels`, ex: `app: cashflow`) e raspar as métricas no endpoint `/metrics`.

### 3.2. Alerting

**Decisão:** **Alertmanager**.
**Justificativa:**

* O Prometheus coleta e armazena as métricas. Quando uma regra de alerta é disparada (ex: `HighErrorRate` ou `PodDown`), o Prometheus envia esse sinal para o **Alertmanager**.
* O Alertmanager é responsável por desduplicar, agrupar e rotear esse alerta para o canal correto (Slack, Email, PagerDuty), garantindo que a equipe saiba que a aplicação está falhando.

---

## 4. Decisão: Resiliência e Disponibilidade

### 4.1. Gerenciamento de Memória (OOMKill)

**Decisão:** Configurar **Requests** e **Limits** de Memória adequados.
**Justificativa:**

* O `OOMKill` ocorre quando o container tenta usar mais memória do que o limite permitido (cgroups).
* Devemos analisar o consumo durante o boot (profiling). Se a aplicação precisa de 512Mi para subir, mas estabiliza em 256Mi, o `limit` deve ser superior a 512Mi (ex: `memory: 600Mi`) para acomodar o pico de inicialização sem ser morto pelo kernel.
* *Configuração sugerida:* Definir `resources.requests.memory` (para agendamento garantido) e `resources.limits.memory` (para teto de consumo).

### 4.2. Probes (Health Checks)

**Decisão:** Implementar **StartupProbe** e **ReadinessProbe**.
**Justificativa:**

* **Problema:** A aplicação demora 30s para conectar ao DB.
* **StartupProbe:** Configuraremos um `startupProbe` com um tempo total de falha > 30s (ex: `failureThreshold: 30` * `periodSeconds: 2`). Isso impede que o Kubernetes mate o container (via Liveness) enquanto ele ainda está inicializando.
* **ReadinessProbe:** Configuraremos o `readinessProbe` para verificar a conexão com o banco. O Kubernetes **só enviará tráfego** (via Service/Ingress) quando este probe retornar sucesso (HTTP 200). Isso garante que nenhum usuário receba erros 500 durante os 30 segundos de inicialização.

---

### Resumo Técnico da Implementação

| Área | Tecnologia/Conceito Escolhido | Benefício Principal |
| --- | --- | --- |
| **Imagem Base** | Wolfi / Distroless | Redução drástica de CVEs (Segurança). |
| **CI Security** | Trivy + Cosign | Bloqueio de vulnerabilidades e garantia de origem. |
| **Ingress** | NGINX + Cert-Manager | Acesso externo seguro (HTTPS) e automatizado. |
| **Metrics** | ServiceMonitor | Auto-discovery de métricas pelo Prometheus. |
| **Alertas** | Alertmanager | Notificação de falhas e incidentes. |
| **Probes** | Readiness & Startup | Zero-downtime deploy e proteção contra lentidão no boot. |