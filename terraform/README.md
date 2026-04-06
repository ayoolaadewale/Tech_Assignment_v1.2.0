# OpsFleet Dev EKS Cluster — Terraform

This repo provisions the shared development Kubernetes cluster on AWS. It creates a VPC, an EKS cluster, a small managed node group for system add-ons, and installs **Karpenter** for on-demand node autoscaling. Developers never need to touch this repo day-to-day — it is maintained by the platform team and applied centrally.

---

## What gets created

| Resource | Details |
|---|---|
| VPC | `10.0.0.0/16`, 3 AZs in `eu-west-1`, public + private subnets, single NAT gateway |
| EKS cluster | `opsfleet-dedicated-dev-eks-cluster`, Kubernetes 1.35 |
| System node group | 2–3 × `m5.large` / `m5a.large` nodes — runs kube-system add-ons only |
| Karpenter | Helm chart `1.10.0` installed into `kube-system` — provisions workload nodes on demand |

---

## Prerequisites (platform team)

- Terraform ≥ 1.5.7
- AWS credentials with permissions to create VPC, EKS, IAM, and EC2 resources
- `helm` and `kubectl` available in `$PATH`

---

## Deploying the infrastructure

```bash
# 1. Initialise providers and modules
terraform init

# 2. Preview changes
terraform plan

# 3. Apply (takes ~15 min on first run)
terraform apply
```

To override a default variable, pass it on the command line:

```bash
terraform apply -var="cluster_version=1.35.3" -var="environment=staging"
```

### Connect kubectl after apply

The `configure_kubectl` output prints the exact command to run:

```bash
terraform output -raw configure_kubectl | bash
# equivalent to:
aws eks update-kubeconfig --region eu-west-1 --name opsfleet-dedicated-dev-eks-cluster
```

---

## For developers — running workloads on the cluster

Karpenter watches for unschedulable pods and launches the right EC2 node automatically. To control **which architecture** your pod lands on, add a `nodeSelector` (or `nodeAffinity`) to your manifest. No manual node provisioning is needed.

### Run on x86 (Intel / AMD)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app-x86
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-app-x86
  template:
    metadata:
      labels:
        app: my-app-x86
    spec:
      nodeSelector:
        kubernetes.io/arch: amd64   # targets x86 nodes
      containers:
        - name: my-app
          image: my-org/my-app:latest
          ports:
            - containerPort: 8080
```

### Run on Graviton (ARM64)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app-graviton
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-app-graviton
  template:
    metadata:
      labels:
        app: my-app-graviton
    spec:
      nodeSelector:
        kubernetes.io/arch: arm64   # targets AWS Graviton nodes
      containers:
        - name: my-app
          image: my-org/my-app:latest-arm64   # use an arm64-compatible image
          ports:
            - containerPort: 8080
```

> **Important:** make sure your container image supports the target architecture. Multi-arch images (built with `docker buildx`) work transparently on both. Single-arch images must match the node's architecture or the pod will fail to start.

### Apply your manifest

```bash
kubectl apply -f deployment.yaml

# Watch Karpenter spin up a node and the pod become ready
kubectl get nodes -w
kubectl get pods -w
```

---

## Key outputs

| Output | Description |
|---|---|
| `cluster_name` | EKS cluster name |
| `cluster_endpoint` | API server endpoint (sensitive) |
| `configure_kubectl` | Ready-to-run `aws eks update-kubeconfig` command |
| `karpenter_node_role` | IAM role name assigned to Karpenter-managed nodes |
| `vpc_id` | VPC ID |
| `private_subnet_ids` | Private subnets used by EKS nodes |

```bash
terraform output           # show all outputs
terraform output -raw configure_kubectl   # get the kubectl config command
```

---

## Variables

| Variable | Default | Description |
|---|---|---|
| `aws_region` | `eu-west-1` | AWS region |
| `cluster_name` | `opsfleet-dedicated-dev-eks-cluster` | EKS cluster name |
| `cluster_version` | `1.35.3` | Kubernetes version |
| `environment` | `development` | Environment tag |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR block |
| `system_node_instance_types` | `["m5.large","m5a.large"]` | Instance types for the system node group |
| `karpenter_version` | `1.10.0` | Karpenter Helm chart version |
