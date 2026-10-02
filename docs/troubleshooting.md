# Enterprise DevOps Troubleshooting Guide

Root-cause diagnosis and fixes for Docker, Magento, Kubernetes, AWS and Terraform issues on the Magento 2 / Adobe Commerce platform.

---

## Table of Contents

1. [Triage First](#triage-first)
2. [Docker & Local Development](#1-docker--local-development)
3. [Magento 2 Application](#2-magento-2-application)
4. [Kubernetes / Amazon EKS](#3-kubernetes--amazon-eks)
5. [AWS Infrastructure](#4-aws-infrastructure)
6. [Terraform](#5-terraform)

---

## Triage First

Work from the outside in, and read the evidence before changing anything:

```bash
kubectl get pods -n magento -o wide                      # state, restarts, node/AZ
kubectl get events -n magento --sort-by=.lastTimestamp   # scheduling, image, volume, probe events
kubectl describe pod <pod> -n magento                    # Last State, exit code, probe failures
kubectl logs <pod> -c php-fpm -n magento --previous      # logs of the crashed container
```

Exit code **137** usually means the container was OOM-killed or killed by a failed probe; **1** is an application error; **126/127** is a command or entrypoint problem.

---

## 1. Docker & Local Development

### Issue: Port conflict (3306 or 8080 already in use)
- **Symptom:** `Bind for 0.0.0.0:3306 failed: port is already allocated`
- **Cause:** a local MySQL (or other) service or an earlier container is using the port.
- **Diagnose:**
  ```bash
  sudo ss -ltnp | grep 3306            # Linux (netstat is deprecated)
  lsof -nP -iTCP:3306 -sTCP:LISTEN     # macOS
  docker ps --filter "publish=3306"
  ```
- **Fix:** stop the conflicting service (`sudo systemctl stop mysql`), or change `MYSQL_PORT` / `WEB_PORT` in `.env` (for example `WEB_PORT=8090`) and recreate the stack. Consider publishing on loopback (`127.0.0.1:3306:3306`) so the service is not exposed to your network.

### Issue: Permission denied on `var/` or `generated/`
- **Symptom:** `chmod(): Operation not permitted`, or `The directory "/var/www/html/var/cache" is not writable by PHP process`.
- **Cause:** file ownership mismatch between the host user and the container's `www-data` (UID 33) on bind-mounted code.
- **Diagnose:**
  ```bash
  docker compose exec magento ls -ld /var/www/html/var /var/www/html/generated
  id -u && id -g       # your host UID/GID
  ```
- **Fix:**
  ```bash
  ./scripts/permissions.sh
  # or manually:
  docker compose exec -u root magento chown -R www-data:www-data \
    /var/www/html/var /var/www/html/generated /var/www/html/pub/static /var/www/html/pub/media
  ```
  - On Linux, running `chown` on a bind mount **changes ownership on your host files** to UID 33, which can stop your editor writing to them. A cleaner long-term setup is to build the image with your UID/GID (build args), or keep `var/`, `generated/` and `pub/static` on named Docker volumes.
  - Never use `chmod 777` as a fix.

---

## 2. Magento 2 Application

### Issue: HTTP 502 Bad Gateway (or 504 Gateway Timeout)
- **Symptom:** the storefront returns 502 from Nginx or from the ALB. **502** means the upstream (PHP-FPM) refused, closed or crashed; **504** means it did not answer within the timeout.
- **Causes:**
  - PHP-FPM crashed, was OOM-killed, or all workers are busy (`server reached pm.max_children` in the PHP-FPM log)
  - Nginx cannot reach PHP-FPM (wrong `fastcgi_pass` host/port or socket)
  - `upstream sent too big header` (Magento sends large cache-tag headers)
  - Request exceeded `request_terminate_timeout` / `fastcgi_read_timeout` (504)
  - In Kubernetes: pods failing readiness, so the ALB has no healthy targets
- **Diagnose:**
  ```bash
  docker compose logs --tail=50 nginx
  docker compose logs --tail=50 magento
  # Kubernetes:
  kubectl logs -n magento -l app.kubernetes.io/component=web-frontend -c php-fpm --tail=50
  kubectl logs -n magento -l app.kubernetes.io/component=web-frontend -c nginx --tail=50
  kubectl top pod -n magento --containers
  kubectl describe pod <pod> -n magento | grep -iE "oomkilled|reason|exit code"
  ```
- **Fix by cause:**
  - **Workers exhausted:** raise `pm.max_children` in `docker/magento/www.conf`, but **size it against memory**: roughly `memory available to PHP / average PHP-FPM worker memory`. With a 4.5 GB container limit, setting it too high just causes OOM kills. Measure real worker memory first and keep headroom for Nginx and OS.
  - **`memory_limit`:** this is a per-request cap, not per-process reservation. Keep it sensible for web requests (higher values such as 2048M are mainly for CLI tasks like compile or reindex) and make sure `children x typical usage` fits in the container.
  - **Big headers:** increase `fastcgi_buffer_size` and `fastcgi_buffers` in the Nginx config (for example `32k` and `16 16k`).
  - **Timeouts:** find the slow request (PHP-FPM slow log, MySQL slow log) before raising timeouts.
  - **Config check:** `docker compose exec magento php-fpm -t` validates the pool configuration.

### Issue: OpenSearch connection failure / catalog search error
- **Symptom:** `Could not connect to OpenSearch at opensearch:9200`, or the search page shows "An error occurred".
- **Causes:** the container is still starting or crashed, `vm.max_map_count` too low, heap too large for the machine, disk watermark reached (indices turn read-only), Magento pointing at the wrong host or engine, or an index mapping error.
- **Diagnose:**
  ```bash
  curl -s "http://localhost:9200/_cluster/health?pretty"
  docker compose logs --tail=50 opensearch
  docker compose exec -u www-data magento bin/magento config:show catalog/search/engine
  docker compose exec -u www-data magento bin/magento config:show catalog/search/opensearch_server_hostname
  docker compose exec -u www-data magento bin/magento indexer:status
  ```
- **Fix:**
  - Linux hosts: `sudo sysctl -w vm.max_map_count=262144`. This does not survive a reboot; persist it in `/etc/sysctl.d/99-opensearch.conf` (`vm.max_map_count=262144`). On Windows with WSL2, set it in the WSL2 VM.
  - Reduce heap on small machines (`OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m`).
  - If the disk is nearly full, free space; indices that were set read-only must be unblocked afterwards.
  - Then reindex:
    ```bash
    docker compose exec -u www-data magento bin/magento indexer:reindex
    docker compose exec -u www-data magento bin/magento cache:flush
    ```

---

## 3. Kubernetes / Amazon EKS

### Issue: Pod in `CrashLoopBackOff`
- **Symptom:** `kubectl get pods -n magento` shows `CrashLoopBackOff` with a rising restart count.
- **Causes:** missing or wrong environment variable or secret value, database or Redis connection refused, **OOMKilled** (exit code 137), failing liveness/startup probe, or **read-only filesystem errors** because a writable path (`var/`, `generated/`, `/tmp`, Nginx cache/run) has no `emptyDir` mount.
- **Diagnose:**
  ```bash
  kubectl describe pod <pod-name> -n magento      # Last State: Terminated -> Reason, Exit Code; probe failures in Events
  kubectl logs <pod-name> -c php-fpm -n magento --previous
  kubectl logs <pod-name> -c nginx -n magento --previous
  ```
- **Fix by cause:**
  - **Database refused or times out:** see [RDS connection timeout](#issue-rds-mysql-connection-timeout) (the RDS security group must allow 3306 from the EKS node security group).
  - **OOMKilled:** lower `pm.max_children` or raise the memory limit.
  - **Probe failure:** check the probe path and port, and the startup probe's failure threshold for slow starts.
  - **`Read-only file system`:** add `emptyDir` volumes for the writable paths.
  - **Secret or config missing:** a missing Secret reference shows as `CreateContainerConfigError`, not CrashLoopBackOff; confirm the Secret exists and was synced (`kubectl get secret -n magento`).

### Issue: `ImagePullBackOff` / `ErrImagePull`
- **Symptom:** the pod cannot start and events show `Failed to pull image ...`.
- **Diagnose:**
  ```bash
  kubectl describe pod <pod-name> -n magento | grep -A 8 Events:
  aws ecr describe-images --repository-name <repo> --image-ids imageTag=<tag> --region <region>
  ```
- **Match the event text to the cause:**

| Event text | Likely cause | Fix |
|---|---|---|
| `not found` / `manifest unknown` | Tag was never pushed, was a typo, or **expired by an ECR lifecycle rule** | Push the image or fix the tag; review lifecycle rules |
| `authorization failed` / `no basic auth credentials` | Node IAM role lacks ECR read access, wrong account/Region in the image URL, or an expired token in a static `imagePullSecret` | Attach `AmazonEC2ContainerRegistryReadOnly` (or `...PullOnly`) to the node role; correct the URL. On EKS, nodes pull with the node role, so a 12-hour ECR token is only relevant if you use an `imagePullSecret` |
| `i/o timeout` / `dial tcp ... timeout` | No network path to ECR from private subnets | Provide NAT, or VPC endpoints for `ecr.api`, `ecr.dkr` and an S3 gateway endpoint, with security groups allowing 443 |
| `no matching manifest for linux/amd64` or `exec format error` | Image built for the wrong CPU architecture (for example arm64 on an amd64 node group) | Build a multi-arch image or match the node architecture |

Note: IRSA and Pod Identity do **not** affect image pulls; the kubelet uses the node role.

### Issue: PersistentVolumeClaim in `Pending`
- **Symptom:** `kubectl get pvc -n magento` stays `Pending`.
- **Causes:**
  - **Normal behaviour:** a StorageClass with `volumeBindingMode: WaitForFirstConsumer` (typical for EBS) keeps the PVC `Pending` until a pod uses it.
  - The CSI driver add-on (`ebs.csi.aws.com` / `efs.csi.aws.com`) is not installed, or its controller lacks IAM permissions (IRSA/Pod Identity role missing).
  - Wrong or missing StorageClass name, or no default StorageClass.
  - EFS: wrong `fileSystemId` in the StorageClass, or a static PV that was never created.
- **Diagnose:**
  ```bash
  kubectl describe pvc magento-media-pvc -n magento    # read the Events at the bottom
  kubectl get storageclass
  kubectl get pods -n kube-system | grep -E "ebs-csi|efs-csi"
  kubectl logs -n kube-system deploy/ebs-csi-controller -c csi-provisioner --tail=50
  ```
- **Fix:** install the add-on (`aws_eks_addon.ebs_csi` / EFS CSI), give its controller an IAM role, correct the StorageClass, and confirm the EFS file system exists in the VPC. For EBS, create a consuming pod before concluding it is stuck.

### Issue: Pod stuck in `ContainerCreating` (EFS mount)
- **Symptom:** events show `MountVolume.SetUp failed ... mount.nfs: Connection timed out`.
- **Cause:** EFS mount target missing in the pod's AZ/subnet, or the EFS security group does not allow **TCP 2049** from the EKS node security group.
- **Fix:** create a mount target in every app AZ and allow 2049 from `eks_nodes_sg`.

### Issue: Ingress has no ADDRESS / no ALB created
- **Symptom:** `kubectl get ingress -n magento` shows an empty ADDRESS.
- **Cause:** AWS Load Balancer Controller not running, missing IAM permissions, subnets not tagged (`kubernetes.io/role/elb`, `kubernetes.io/role/internal-elb`), or an invalid annotation or certificate ARN.
- **Diagnose:** `kubectl describe ingress -n magento` and `kubectl logs -n kube-system deploy/aws-load-balancer-controller`.

---

## 4. AWS Infrastructure

### Issue: RDS MySQL connection timeout
- **Symptom:** `SQLSTATE[HY000] [2002] Connection timed out` from a Magento pod.
- **Causes:** the RDS security group does not allow the pod's source on 3306, RDS is in the wrong VPC or subnets, a network ACL blocks traffic, or the application uses the wrong endpoint. If pods use *security groups for pods*, their source is the pod SG, not the node SG.
- **Tell errors apart:** `[2002] timed out` is a network or security-group block; `[2002] Connection refused` means nothing is listening or the host is wrong; `[1045] Access denied` is credentials; `[1040] Too many connections` is `max_connections` exhausted.
- **Diagnose:**
  ```bash
  aws ec2 describe-security-group-rules --filters Name=group-id,Values=<rds-sg-id>
  # Test from inside the cluster (use an image allowed by your Pod Security profile):
  kubectl run netshoot --rm -it --image=nicolaka/netshoot -n <test-namespace> -- nc -zv <rds-endpoint> 3306
  ```
- **Fix:** allow the EKS node security group on 3306. With the current AWS provider, prefer standalone rule resources (do not mix them with inline `ingress` blocks on the same security group):
  ```hcl
  resource "aws_vpc_security_group_ingress_rule" "rds_from_eks_nodes" {
    security_group_id            = module.security_groups.rds_security_group_id
    referenced_security_group_id = module.security_groups.eks_nodes_security_group_id
    from_port                    = 3306
    to_port                      = 3306
    ip_protocol                  = "tcp"
  }
  ```
  The same pattern applies to Redis (6379), OpenSearch (443), Amazon MQ (5671) and EFS (2049).

---

## 5. Terraform

### Issue: `Error acquiring the state lock`
- **Symptom:**
  - S3 native locking: an error mentioning `PreconditionFailed` on the `.tflock` object
  - Legacy DynamoDB locking: `ConditionalCheckFailedException: The conditional request failed`

  Both print **Lock Info** (ID, Path, Operation, Who, Created).
- **Cause:** either another run **legitimately holds the lock** (a teammate or CI pipeline applying right now), or an earlier run was killed (Ctrl+C, cancelled CI job, crash) and never released it.
- **Diagnose:** first confirm nobody is running an apply (check CI and ask the team), and read the `Who` and `Created` fields. Then inspect the lock:
  ```bash
  # S3 native locking: the lock is an object next to the state file
  aws s3api head-object --bucket <state-bucket> --key magento/prod/terraform.tfstate.tflock
  aws s3 cp s3://<state-bucket>/magento/prod/terraform.tfstate.tflock -

  # Legacy DynamoDB locking: the lock item key is "<bucket>/<key>".
  # (The item ending in -md5 only stores the state digest, not the lock.)
  aws dynamodb get-item --table-name magento2-devops-terraform-locks \
    --key '{"LockID": {"S": "<state-bucket>/magento/prod/terraform.tfstate"}}'
  ```
- **Fix:** only when you are sure the holder is dead, unlock using the ID from the error message, from the same environment directory:
  ```bash
  terraform force-unlock <LOCK-ID>
  ```
  - Never force-unlock while an apply is genuinely running; two concurrent applies can corrupt state.
  - Prefer cancelling CI jobs gracefully so Terraform can release the lock itself.
  - After a killed apply, run `terraform plan` to reconcile. If state looks damaged, restore a previous version from the state bucket's versioning.
