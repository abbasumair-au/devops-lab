# devops-lab

A local DevOps lab running on Windows via WSL2 + Docker Desktop. Built to practice and maintain hands-on skills in Kubernetes, Terraform, Helm, ArgoCD, Prometheus, and Grafana — without cloud costs.

---

## Stack

| Tool | Purpose |
|------|---------|
| kind | Local Kubernetes cluster inside Docker |
| Terraform | Provision the kind cluster as code |
| Helm | Package and deploy apps to Kubernetes |
| ArgoCD | GitOps — auto-sync deployments from this repo |
| Prometheus | Metrics collection and alerting |
| Grafana | Dashboards and visualization |
| GitHub Actions | CI — lint and validate on every push |

---

## Architecture

```
GitHub repo (this)
    │
    └─► ArgoCD (watches repo, auto-deploys on push)
            │
            ▼
    kind cluster (local, 2 nodes)
    ├── myapp (Helm chart, nginx)
    ├── ArgoCD
    ├── Prometheus (scrapes cluster metrics)
    └── Grafana (dashboards on top of Prometheus)

Terraform provisions the cluster.
GitHub Actions runs CI on every push.
```

---

## Prerequisites

- Windows 10/11
- Docker Desktop (WSL2 backend enabled)
- Ubuntu via WSL2

---

## Phase 1 — Install Tools (Ubuntu WSL terminal)

```bash
# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# kind
curl -Lo kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64
chmod +x kind && sudo mv kind /usr/local/bin/

# helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# terraform
sudo apt update && sudo apt install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# argocd CLI
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd && sudo mv argocd /usr/local/bin/
```

---

## Phase 2 — Clone and Structure the Repo

```bash
git clone https://github.com/abbasumair-au/devops-lab.git
cd devops-lab
mkdir -p terraform helm-charts apps monitoring .github/workflows
```

> **Auth note:** GitHub requires a Personal Access Token (PAT), not your password.  
> Generate one at: GitHub → Settings → Developer settings → Tokens (classic) → scope: `repo`

---

## Phase 3 — Provision the Cluster with Terraform

```bash
cd terraform
terraform init
terraform apply
```

Provisions a local 2-node Kubernetes cluster using the `tehcyx/kind` Terraform provider.

Verify:
```bash
kubectl get nodes
```

### Teardown / Recreate

If the cluster is lost after a Docker Desktop restart:

```bash
terraform state rm kind_cluster.lab
kind delete cluster --name devops-lab
terraform apply -auto-approve
```

---

## Phase 4 — Install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available --timeout=180s deployment/argocd-server -n argocd
```

Access the UI:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open: `https://localhost:8080`  
Username: `admin`  
Password:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

---

## Phase 5 — Deploy Sample App via Helm + ArgoCD

Create the Helm chart:
```bash
cd helm-charts
helm create myapp
git add . && git commit -m "add myapp helm chart" && git push
```

In ArgoCD UI → New App:

| Field | Value |
|-------|-------|
| App name | `myapp` |
| Project | `default` |
| Sync policy | Automatic |
| Repo URL | `https://github.com/abbasumair-au/devops-lab` |
| Path | `helm-charts/myapp` |
| Cluster | `https://kubernetes.default.svc` |
| Namespace | `default` |

Every push to this repo auto-deploys via ArgoCD.

---

## Phase 6 — Install Prometheus + Grafana

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

Access:
```bash
# Grafana
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80

# Prometheus
kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090
```

| Tool | URL | Login |
|------|-----|-------|
| Grafana | http://localhost:3000 | admin / prom-operator |
| Prometheus | http://localhost:9090 | none |

---

## Phase 7 — GitHub Actions CI

Located at `.github/workflows/ci.yml`.

Runs on every push to `main`:
- Helm chart linting
- Terraform validation

---

## Every time you restart

Docker Desktop must be running first. Then in Ubuntu:

```bash
# Check cluster is up
kubectl get nodes

# Re-run port-forwards (one per terminal tab)
kubectl port-forward svc/argocd-server -n argocd 8080:443
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80
kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090
```

---

## Repo Structure

```
devops-lab/
├── terraform/              # Cluster provisioning
│   └── main.tf
├── helm-charts/            # Helm charts
│   └── myapp/
├── apps/                   # ArgoCD app manifests
├── monitoring/             # Custom Prometheus rules, Grafana dashboards
└── .github/
    └── workflows/
        └── ci.yml
```

---

## Future Projects

| # | Project | Skills |
|---|---------|--------|
| 1 | ✅ Local cluster + ArgoCD GitOps loop | Terraform, kind, Helm, ArgoCD |
| 2 | Add ServiceMonitor — scrape app metrics with Prometheus | Prometheus, ServiceMonitor CRD |
| 3 | Build custom Grafana dashboard for myapp | Grafana, PromQL |
| 4 | Add Prometheus alert rule — fire when pod is down | Alerting, PrometheusRule CRD |
| 5 | Simulate pod failure — debug with kubectl | kubectl logs, describe, events |
| 6 | Deploy a real Python Flask app via Helm + ArgoCD | Docker, GHCR, Helm, Python |
| 7 | Add resource limits and PodDisruptionBudget | Kubernetes resource management |
| 8 | Multi-environment setup (dev/staging namespaces) | ArgoCD ApplicationSets, Helm values |
| 9 | Terraform remote state with Azure Blob Storage | Terraform backends, Azure |
| 10 | Add Ansible playbook to configure WSL environment | Ansible |

---

## Certifications

CKA · Terraform Associate · AZ-305 · AZ-400
