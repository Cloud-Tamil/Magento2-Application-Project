# Kubernetes Architecture & Manifest Guide

Pure Kubernetes specifications for running Magento 2 / Adobe Commerce on **Amazon EKS**. This folder is the application layer only; AWS infrastructure (VPC, EKS, RDS, ElastiCache, OpenSearch, Amazon MQ, EFS) is provisioned separately.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Manifest Catalog](#2-manifest-catalog)
3. [Design Notes](#3-design-notes)
4. [Deployment Sequence to EKS](#4-deployment-sequence-to-eks)
5. [Verification](#5-verification)
6. [Rollback](#6-rollback)

---

## 1. Prerequisites

These must already exist in the cluster **before** applying any manifest:

| Requirement | Why |
|---|---|
| AWS Load Balancer Controller | Turns the `Ingress` into an ALB |
| EFS CSI driver | `ReadWriteMany` volume for `pub/media` |
| EBS CSI driver | Only if the `gp3` StorageClass is used by any workload |
| metrics-server | Required by the HPA (CPU and memory metrics) |
| IRSA / Pod Identity (IAM role for the ServiceAccount) | Passwordless access to AWS Secrets Manager |
| Secret sync mechanism | External Secrets Operator or Secrets Store CSI Driver (AWS provider) |
| Container image in ECR | Built in CI with code compiled and static assets baked in |
| Data tier reachable from nodes | RDS (3306), Redis (6379), OpenSearch (443), RabbitMQ (5671), EFS (2049) |

---

## 2. Manifest Catalog

The `kubernetes/` folder contains:

| # | File | Purpose |
|---|---|---|
| 1 | `namespace.yaml` | Isolated `magento` namespace with Pod Security Admission labels (baseline enforced; aim for `restricted` where the images allow) |
| 2 | `configmap.yaml` | Non-sensitive configuration: base URL, hostnames, ports, locales |
| 2a | `config/magento-config.yaml` | Additional Magento configuration (applied in the deployment sequence; keep it listed here so the catalog matches the commands) |
| 3 | `secret.example.yaml` | **Schema only** of the required credentials. Never apply it to production; real values are synced from AWS Secrets Manager |
| 4 | `deployment.yaml` | Two-container pod (Nginx + PHP-FPM), probes, resources, `magento-web` |
| 5 | `service.yaml` | Service in front of the web pods (see [Design Notes](#service-and-ingress)) |
| 6 | `ingress.yaml` | ALB via AWS Load Balancer Controller, TLS with an ACM certificate |
| 7 | `hpa.yaml` | HorizontalPodAutoscaler, 3 to 15 replicas, CPU 70% and memory 80% |
| 8 | `pdb.yaml` | PodDisruptionBudget keeping at least 2 pods available during node drains and upgrades |
| 9 | `serviceaccount.yaml` | ServiceAccount annotated with the IRSA role ARN |
| 10 | `storage/storageclass.yaml`, `storage/pvc.yaml` | EBS gp3 (block, RWO) and EFS (shared media, RWX) |
| 11 | `cronjob.yaml` | Runs `bin/magento cron:run` every minute with `concurrencyPolicy: Forbid` |
| 12 | `jobs/` | One-off operational Jobs: setup upgrade, reindex, cache flush |

---

## 3. Design Notes

### Deployment (`deployment.yaml`)
- **Nginx** serves static assets and handles internal HTTP (TLS terminates at the ALB). **PHP-FPM** runs the Magento application. They talk over localhost (a TCP port or a Unix socket on a shared `emptyDir`).
- Nginx needs the `pub/static` files. Bake them into the Nginx image, or copy them with an init container into a shared volume. `pub/media` comes from the EFS volume.
- **Code compilation happens at image build time** (`setup:di:compile`, static content deploy), not at pod start. The startup, readiness and liveness probes confirm that Nginx, PHP-FPM and the application bootstrap are up, so no traffic is routed to a pod that isn't ready. They don't compile anything.
- **Resources:** requests 1.25 CPU / 2.25 GB RAM, limits 3 CPU / 4.5 GB RAM. State clearly in the manifest whether these are per pod or per container, and use `Gi` units. CPU limits can cause throttling, so consider keeping the CPU request and relaxing the CPU limit.
- Do **not** set `spec.replicas` in the Deployment when an HPA manages it, otherwise every `kubectl apply` resets the replica count.
- Recommended: `topologySpreadConstraints` across AZs, a `preStop` delay with a suitable `terminationGracePeriodSeconds` for graceful draining, `runAsNonRoot`, and a read-only root filesystem with `emptyDir` for writable paths such as `var/` and `generated/`.

### Service and Ingress
- Use a **`ClusterIP`** Service and set `alb.ingress.kubernetes.io/target-type: ip` on the Ingress, so the ALB sends traffic directly to pod IPs. A `NodePort` Service adds an unnecessary hop and is only needed for `target-type: instance`.
- Typical Ingress annotations: `alb.ingress.kubernetes.io/scheme: internet-facing`, `listen-ports` (80 and 443), `ssl-redirect: '443'`, `certificate-arn` (or ACM discovery by host), `ssl-policy` (TLS 1.2+), and `healthcheck-path`.

### Autoscaling and disruption
- The HPA needs metrics-server. CPU utilisation is calculated against the pod's **requests**. Memory is a weak scaling signal for PHP-FPM, so prefer CPU (or request-based metrics) as the primary driver.
- `pdb.yaml` (`minAvailable: 2`) works with the HPA minimum of 3 replicas, so one pod at a time can be evicted during node upgrades. Keep `minAvailable` below `minReplicas`.

### Storage
- **EFS (`ReadWriteMany`)** is for shared `pub/media`. Use the EFS CSI driver with a StorageClass (`provisioner: efs.csi.aws.com`, access-point provisioning with the file system ID).
- **EBS gp3 is block storage and `ReadWriteOnce`**, so it cannot be shared across web replicas. Keep it only for workloads that genuinely need a per-pod disk. If you create it, set `volumeBindingMode: WaitForFirstConsumer` so the volume is created in the same AZ as the pod.

### CronJob
- `bin/magento cron:run` every minute (`* * * * *`, the smallest CronJob interval). `concurrencyPolicy: Forbid` skips a run if the previous one is still active.
- Also set `startingDeadlineSeconds`, `successfulJobsHistoryLimit`, `failedJobsHistoryLimit` and resource limits.

### Jobs (`jobs/`)
- A Job's pod template is **immutable**, so re-running `kubectl apply` on an existing Job fails. Create a uniquely named Job per run (`generateName` with `kubectl create`), or delete the old one first, and set `ttlSecondsAfterFinished` for cleanup.
- Run **setup upgrade before** rolling out new web pods, and **cache flush / reindex after**. On a brand-new environment the first run is `setup:install`, not `setup:upgrade`.

### Secrets
- `secret.example.yaml` documents the required keys only. In production the `magento` namespace Secret is created by External Secrets Operator or the Secrets Store CSI Driver from AWS Secrets Manager, using the ServiceAccount's IAM role.
- Enable EKS envelope encryption (KMS) for Kubernetes Secrets, and restrict RBAC on them.

---

## 4. Deployment Sequence to EKS

Apply in this order so each resource's dependencies exist first. File names under `jobs/` are examples; use your actual file names.

```bash
# 1. Connect kubectl to the EKS cluster
aws eks update-kubeconfig --region us-east-1 --name magento-prod-eks

# 2. Verify nodes and cluster add-ons (LB controller, CSI drivers, metrics-server)
kubectl get nodes -o wide
kubectl get pods -n kube-system

# 3. Create the namespace
kubectl apply -f kubernetes/namespace.yaml

# 4. ServiceAccount first (IRSA), so secret sync can use it
kubectl apply -f kubernetes/serviceaccount.yaml

# 5. StorageClass and PersistentVolumeClaims
kubectl apply -f kubernetes/storage/storageclass.yaml
kubectl apply -f kubernetes/storage/pvc.yaml

# 6. Configuration
kubectl apply -f kubernetes/configmap.yaml
kubectl apply -f kubernetes/config/magento-config.yaml

# 7. Secrets: sync from AWS Secrets Manager (External Secrets / Secrets Store CSI).
#    Do NOT apply secret.example.yaml to production: it holds placeholders only.
#    Confirm the real Secret exists before continuing:
kubectl get secret -n magento

# 8. Pre-deploy: database schema upgrade (once per release)
kubectl create -f kubernetes/jobs/setup-upgrade.yaml
kubectl wait --for=condition=complete job -l app=magento-setup-upgrade -n magento --timeout=15m

# 9. Deploy application, networking and scaling
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
kubectl apply -f kubernetes/ingress.yaml
kubectl apply -f kubernetes/hpa.yaml
kubectl apply -f kubernetes/pdb.yaml

# 10. CronJob
kubectl apply -f kubernetes/cronjob.yaml

# 11. Wait for the rollout
kubectl rollout status deployment/magento-web -n magento

# 12. Post-deploy: cache flush (and reindex if the release requires it)
kubectl create -f kubernetes/jobs/cache-flush.yaml
```

> **Tip:** wrapping the manifests in a `kustomization.yaml` and using `kubectl apply -k` (or Helm / GitOps) removes ordering mistakes, but keep the Job steps (8 and 12) separate because they must run before and after the rollout.

---

## 5. Verification

```bash
kubectl get pods -n magento -o wide          # pods Running/Ready, spread across AZs
kubectl get hpa,pdb -n magento               # HPA shows real metrics, PDB allowed disruptions
kubectl get ingress -n magento               # ALB address assigned
kubectl get cronjob,jobs -n magento          # cron running, setup job Complete
kubectl logs deploy/magento-web -n magento -c php-fpm --tail=50
```

Then confirm the ALB target group shows healthy targets and the storefront and admin load over HTTPS.

---

## 6. Rollback

```bash
kubectl rollout undo deployment/magento-web -n magento
kubectl rollout status deployment/magento-web -n magento
```

`rollout undo` reverts the application image only. It does not revert database schema changes made by `setup:upgrade`, so keep schema changes backward-compatible between releases and see the Backup & Disaster Recovery section of the main README for database restore procedures.
