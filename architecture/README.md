## High Level Design Multi-Accoutn Setup

Innovate Inc. should adopt a multi-account AWS organisation from day one. It is the minimum viable security posture for a company handling sensitive user data. A single AWS account for everything creates blast radius problems: a misconfigured IAM role, a compromised access key, or a runaway script can affect all environments simultaneously.

The recommended structure uses four accounts managed under a single AWS Organisation with consolidated billing:

| Account	| Purpose |	Contents | Network Access
|---|---|---|---|
| Management | Billing, SSO, governance	| AWS Organizations, IAM Identity Center, CloudTrail org-level, Cost Explorer |	No workloads — admin only
| Production | Live customer traffic | EKS prod cluster, RDS prod, all customer-facing services	| Restricted; no direct developer access
| Staging | Pre-production validation | EKS staging cluster, RDS staging, mirrors prod topology |	Dev team access for debugging
| Development | Active development & CI | EKS dev cluster, RDS dev, CI/CD runners | Open developer access

Justification
1. Blast radius containment: A security incident in Development cannot reach Production credentials, data, or network.

2. Compliance boundary: Sensitive user data in Production is isolated. Audit logs (CloudTrail) are centralised in the Management account, where developers cannot tamper with them.

3. Cost visibility: Each account maps to a business environment. Engineers immediately see the cost of their workloads without manual tagging gymnastics.

4. Permission model: Developers log into IAM Identity Center once and assume roles into the appropriate account with only the permissions they need — read-only in Production by default, admin in Development.

## Network Design (VPC)

Architecture: A Regional VPC spanning three Availability Zones (AZs) for high availability.

Subnet Strategy:
Public Subnets: Host the Application Load Balancer (ALB) and NAT Gateways.

Private Subnets: Host the EKS Worker Nodes (managed by Karpenter). No direct internet access.

Isolated Subnets: Dedicated subnets for the RDS PostgreSQL database with no route to the internet.

Security Layers:
AWS WAF (Web Application Firewall): Positioned in front of the ALB to block SQL injection and Cross-Site Scripting (XSS).

Security Groups: Implement the "Principle of Least Privilege."

ALB SG: Allows HTTPS (443) from the internet.

EKS Node SG: Allows traffic only from the ALB SG.

RDS SG: Allows traffic only from the EKS Node SG on port 5432.

## Compute Platform: Managed Kubernetes (EKS)

We will utilize Amazon EKS as the orchestration engine, optimized for cost-efficiency.

Node Management & Scaling:
Controller: A small, stable EKS Managed Node Group (2x t3.medium) to run critical "System" pods like CoreDNS and the Karpenter controller.

Dynamic Scaling (Karpenter): Karpenter will manage all "Application" workloads. It will be configured to:

Prioritize Graviton (arm64): To leverage the 40% better price/performance

Utilize Spot Instances: For the non-prod environments (with a fallback to On-Demand in staging) to reduce costs by up to 70%.

Automatic Consolidation: Karpenter will actively terminate underutilized nodes and reschedule pods to pack instances efficiently.

Pod Disruption Budgets
PodDisruptionBudgets (PDBs) are defined for all production deployments to guarantee a minimum number of available replicas during node disruption events (rolling updates, Karpenter consolidation, AZ failures):

## Containerization & CI/CD:
Registry: Amazon ECR (Private) with "Scan on Push" enabled to detect vulnerabilities in Python/React libraries. Trivy scan can also be implemented here as one of the steps in CI?CD when image is been built

Image Building: Multi-stage Docker builds to keep image sizes small (using python:3.12-slim and node:alpine). Trivy scan can also be implemented here as one of the steps in CI?CD when image is been built to scan for vulnerabilities

Lifecycle policies on ECR automatically expire untagged images older than 30 days to control storage costs.

Deployment Process:
Deployments follow a GitOps model: the Git repository is the single source of truth for the desired cluster state. No developer runs kubectl apply in production manually.

Developer pushes code to GitHub.

GitHub Actions builds the image and pushes to ECR.

A Helm chart is updated, and ArgoCD (or a simple kubectl apply) syncs the state to the EKS cluster.

## Database

Amazon RDS for PostgreSQL is the recommended database service. RDS manages OS patching, minor version upgrades, automated backups, and Multi-AZ failover.

Justification:
Managed Patching: AWS handles OS and DB engine security updates.
Multi-AZ Deployment: RDS automatically maintains a synchronous standby in a different AZ. If the primary fails, it fails over in <60 seconds with no manual intervention.

### High Availability
Multi-AZ Deployment
RDS Multi-AZ maintains a synchronous standby replica in a second Availability Zone. AWS monitors the primary and promotes the standby automatically if:
•	The primary instance or its underlying hardware fails
•	The Availability Zone suffers a service disruption
•	A maintenance window triggers a restart

Failover time: 60–120 seconds automatically, with no application code change required. The RDS endpoint DNS record is updated to point to the promoted standby.

Read Replicas
As traffic grows, read-heavy queries (reporting, analytics, listing endpoints) should be directed to one or more Read Replicas. Read Replicas are asynchronous replicas that can also serve as a warm standby for disaster recovery in a second AWS Region.

### Backups & DR
Daily Snapshots: Retained for 35 days.

Point-in-Time Recovery (PITR): Allows restoring the database to any specific second within the retention period (critical for accidental data deletion).

Same-region restore from snapshot: 15–45 minutes. Used for logical errors (accidental data deletion) when Multi-AZ failover does not help.

Cross-region disaster recovery: 2–4 hours. Restore the latest cross-region snapshot into a new RDS instance in the DR region and update the application connection string.

### High-Level Architectural Diagram
This diagram captures the production environment flow:

Infrastructure Layout: Shows the VPC spanning three Availability Zones for high availability.

Networking: Illustrates the traffic flow from the internet, through AWS WAF and the ALB, into the private EKS pods.

Compute Tier: Highlights the managed "System" Node Group (running Karpenter) and the dynamic "Karpenter-Managed Capacity Pool," explicitly differentiating between Graviton (arm64) and x86 (amd64) nodes.

Data Tier: Shows the Amazon RDS Multi-AZ deployment with synchronous replication.

Integrations: Includes peripheral services like CI/CD pipelines, Amazon ECR, and encryption/management tools.
![alt text](image.png)