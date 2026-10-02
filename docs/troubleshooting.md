# Enterprise DevOps Troubleshooting Guide

This guide details root-cause diagnosis and fixes for Docker, Magento, Kubernetes, AWS, and Terraform.

---

## 1. Docker & Local Development

### Issue: Port Conflict (3306 or 8080 already in use)
- **SYMPTOM**: `Error response from daemon: driver failed programming external connectivity on endpoint: Bind for 0.0.0.0:3306 failed: port is already allocated`
- **CAUSE**: A local MySQL service or previous Docker container is occupying port 3306 or 8080.
- **DIAGNOSIS COMMAND**:
  ```bash
  sudo lsof -i :3306 || sudo netstat -tulpn | grep 3306
  docker ps --filter "publish=3306"
  ```
- **FIX**: Either stop the conflicting local service (`sudo systemctl stop mysql`) or update `MYSQL_PORT` / `WEB_PORT` in your `.env` file (e.g., `WEB_PORT=8090`).

### Issue: Container Permission Denied on `var/` or `generated/`
- **SYMPTOM**: `chmod(): Operation not permitted` or `The directory "/var/www/html/var/cache" is not writable by PHP process`.
- **CAUSE**: UID mismatch between host user and container's `www-data` user (UID 33).
- **DIAGNOSIS COMMAND**:
  ```bash
  docker compose exec magento ls -ld /var/www/html/var
  ```
- **FIX**: Run the permissions fixer script:
  ```bash
  ./scripts/permissions.sh
  # Or inside container:
  docker compose exec -u root magento chown -R www-data:www-data /var/www/html/var /var/www/html/generated /var/www/html/pub/static
  ```

---

## 2. Magento 2 Application

### Issue: HTTP 502 Bad Gateway
- **SYMPTOM**: Nginx responds with `502 Bad Gateway`.
- **CAUSE**: PHP-FPM process crashed, PHP pool children exhausted, or PHP crashed due to `memory_limit` exhaustion.
- **DIAGNOSIS COMMAND**:
  ```bash
  docker compose logs --tail=50 nginx
  docker compose logs --tail=50 magento
  # In Kubernetes:
  kubectl logs -n magento -l app.kubernetes.io/component=web-frontend -c php-fpm --tail=50
  ```
- **FIX**: Increase `pm.max_children` in `docker/magento/www.conf` and ensure `memory_limit = 2048M` in `docker/magento/php.ini`.

### Issue: OpenSearch Connection Failure / Catalog Search Error
- **SYMPTOM**: `Could not connect to OpenSearch at opensearch:9200` or catalog search page displays "An error occurred".
- **CAUSE**: OpenSearch container is initializing, memory lock failed, or index mapping error.
- **DIAGNOSIS COMMAND**:
  ```bash
  curl -I http://localhost:9200
  docker compose exec -u www-data magento bin/magento indexer:status
  ```
- **FIX**:
  Ensure host virtual memory settings are applied (`sudo sysctl -w vm.max_map_count=262144`). Then reindex:
  ```bash
  docker compose exec -u www-data magento bin/magento indexer:reindex
  docker compose exec -u www-data magento bin/magento cache:flush
  ```

---

## 3. Kubernetes / Amazon EKS

### Issue: Pod in `CrashLoopBackOff`
- **SYMPTOM**: `kubectl get pods -n magento` reports pod state `CrashLoopBackOff` with restart count > 0.
- **CAUSE**: Missing environment variable, database connection refusal, or failure of startup/liveness probe.
- **DIAGNOSIS COMMAND**:
  ```bash
  kubectl describe pod <pod-name> -n magento
  kubectl logs <pod-name> -c php-fpm -n magento --previous
  ```
- **FIX**: Check the `Last State: Terminated` reason. If DB connection fails, ensure RDS security group allows port 3306 from the EKS worker nodes security group.

### Issue: `ImagePullBackOff` / `ErrImagePull`
- **SYMPTOM**: Pod cannot start; events show `Failed to pull image ... authorization failed`.
- **CAUSE**: Amazon ECR token expired, worker node IAM role lacks `AmazonEC2ContainerRegistryReadOnly`, or image tag does not exist.
- **DIAGNOSIS COMMAND**:
  ```bash
  kubectl describe pod <pod-name> -n magento | grep -A 5 Events:
  ```
- **FIX**: Ensure the EKS Node IAM role has `AmazonEC2ContainerRegistryReadOnly` attached, and verify that the image tag was pushed to the target ECR repository URL.

### Issue: PersistentVolumeClaim in `Pending`
- **SYMPTOM**: `kubectl get pvc -n magento` stays in `Pending` state indefinitely.
- **CAUSE**: StorageClass provisioner `ebs.csi.aws.com` or `efs.csi.aws.com` addon is not installed or lacks IAM permissions.
- **DIAGNOSIS COMMAND**:
  ```bash
  kubectl describe pvc magento-media-pvc -n magento
  kubectl get storageclass
  ```
- **FIX**: Ensure AWS EBS/EFS CSI driver addon is installed (`aws_eks_addon.ebs_csi`) and that the EFS filesystem exists in the VPC.

---

## 4. AWS Infrastructure

### Issue: RDS MySQL Connection Timeout
- **SYMPTOM**: `SQLSTATE[HY000] [2002] Connection timed out` from Magento pod.
- **CAUSE**: EKS worker node security group is not allowed in the RDS security group on port 3306, or RDS was provisioned in wrong VPC subnets.
- **DIAGNOSIS COMMAND**:
  ```bash
  aws ec2 describe-security-group-rules --filter "Name=group-id,Values=<rds-sg-id>"
  ```
- **FIX**: Verify Terraform security group rule:
  ```hcl
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [module.security_groups.eks_nodes_security_group_id]
  }
  ```

---

## 5. Terraform

### Issue: `Error acquiring the state lock`
- **SYMPTOM**: `Error: Error acquiring the state lock: ConditionalCheckFailedException: The conditional request failed`
- **CAUSE**: A previous `terraform apply` was terminated abnormally (e.g. CTRL+C or CI job cancel), leaving an active lock ID in DynamoDB.
- **DIAGNOSIS COMMAND**:
  ```bash
  aws dynamodb get-item --table-name magento2-devops-terraform-locks --key '{"LockID": {"S": "prod/terraform.tfstate-md5"}}'
  ```
- **FIX**: Unlock using the Lock ID reported in the Terraform error message:
  ```bash
  terraform force-unlock <LOCK-ID>
  ```
