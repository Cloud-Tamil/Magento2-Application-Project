# Kubernetes Architecture & Manifest Guide

## Manifest Catalog

The `kubernetes/` folder contains pure Kubernetes specifications:

1. `namespace.yaml`: Defines `magento` isolated namespace with Pod Security baseline labels.
2. `configmap.yaml`: Non-sensitive application configuration (base URL, hostnames, ports, locales).
3. `secret.example.yaml`: Schema of required credentials. In production, synchronized from AWS Secrets Manager.
4. `deployment.yaml`: Dual-container pod pattern (Nginx + PHP-FPM).
   - Nginx handles static assets and terminates internal HTTP.
   - PHP-FPM executes Magento 2 application logic.
   - Liveness, readiness, and startup probes prevent traffic routing before DI compilation is ready.
   - Strict resource limits (Requests: 1.25 CPU, 2.25GB RAM; Limits: 3 CPU, 4.5GB RAM).
5. `service.yaml`: Internal NodePort service routing traffic from ALB.
6. `ingress.yaml`: Ingress utilizing the AWS Load Balancer Controller with automated ACM TLS termination.
7. `hpa.yaml`: Horizontal Pod Autoscaler scaling from 3 to 15 replicas based on CPU (70%) and Memory (80%).
8. `pdb.yaml`: Pod Disruption Budget guaranteeing minimum 2 pods remain online during cluster upgrades.
9. `serviceaccount.yaml`: ServiceAccount annotated with IRSA role for passwordless AWS Secrets Manager access.
10. `storage/storageclass.yaml` & `storage/pvc.yaml`: EBS GP3 (block) and EFS (ReadWriteMany shared media).
11. `cronjob.yaml`: Runs `bin/magento cron:run` every 60 seconds with strict `concurrencyPolicy: Forbid`.
12. `jobs/`: Setup upgrade, reindex, and cache flush operational batch jobs.

## Deployment Sequence to EKS

```bash
# 1. Connect kubectl to EKS cluster
aws eks update-kubeconfig --region us-east-1 --name magento-prod-eks

# 2. Verify cluster nodes
kubectl get nodes -o wide

# 3. Create namespace
kubectl apply -f kubernetes/namespace.yaml

# 4. Apply StorageClass and Persistent Volume Claims
kubectl apply -f kubernetes/storage/storageclass.yaml
kubectl apply -f kubernetes/storage/pvc.yaml

# 5. Apply ConfigMaps and Secrets
kubectl apply -f kubernetes/configmap.yaml
kubectl apply -f kubernetes/config/magento-config.yaml
# Ensure real secrets are created:
kubectl apply -f kubernetes/secret.example.yaml

# 6. Apply RBAC and ServiceAccount
kubectl apply -f kubernetes/serviceaccount.yaml

# 7. Deploy Application & Ingress
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
kubectl apply -f kubernetes/ingress.yaml
kubectl apply -f kubernetes/hpa.yaml
kubectl apply -f kubernetes/pdb.yaml

# 8. Deploy CronJob
kubectl apply -f kubernetes/cronjob.yaml

# 9. Verify Rollout
kubectl rollout status deployment/magento-web -n magento
kubectl get pods -n magento -o wide
kubectl get ingress -n magento
```
