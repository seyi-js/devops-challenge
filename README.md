# DevOps Challenge — Production-Ready Application Deployment

A production-ready deployment of a Node.js microservice on AWS EC2, with a full CI/CD pipeline (GitHub Actions), Infrastructure as Code (Terraform), and CloudWatch monitoring.

---

## Architecture Overview

```
                          ┌────────────────────────────────────────────────────┐
                          │                    AWS (us-east-1)                 │
                          │                                                    │
  Internet                │  ┌─────────────────────────────────────────────┐  │
  ─────────►  ALB :80     │  │             VPC  10.0.0.0/16                │  │
             (public)     │  │                                             │  │
                          │  │  Public Subnets (AZ-a, AZ-b)               │  │
                          │  │  ┌──────────┐  ┌──────────┐               │  │
                          │  │  │ 10.0.1.0 │  │ 10.0.2.0 │  ← ALB       │  │
                          │  │  └──────────┘  └──────────┘               │  │
                          │  │        │               │                   │  │
                          │  │   NAT GW             NAT GW               │  │
                          │  │        └──────┬────────┘                  │  │
                          │  │               ▼                           │  │
                          │  │  Private Subnet (AZ-a)                    │  │
                          │  │  ┌──────────────────────────┐             │  │
                          │  │  │  EC2 t3.small (Docker)   │             │  │
                          │  │  │  devops-app :3000         │             │  │
                          │  │  └──────────────────────────┘             │  │
                          │  └─────────────────────────────────────────────┘  │
                          │                                                    │
                          │  ECR (images)   CloudWatch (logs/metrics/alarms)  │
                          └────────────────────────────────────────────────────┘
                                        ▲
                                        │  SSM Run Command (no port 22)
                                  ┌─────────────────┐
                                  │ GitHub Actions   │
                                  │ (ubuntu-latest)  │
                                  └─────────────────┘
                                        ▲
                                        │  push to main
                                  ┌─────────────────┐
                                  │ GitHub Repo      │
                                  └─────────────────┘
```

### Component Summary

| Component          | Technology                   | Purpose                                         |
| ------------------ | ---------------------------- | ----------------------------------------------- |
| Application        | Node.js + Express            | Lightweight HTTP service                        |
| Containerisation   | Docker (multi-stage)         | Reproducible, minimal production image          |
| Container Registry | AWS ECR                      | Stores versioned Docker images                  |
| Compute            | AWS EC2 (t3.small)           | Runs the Docker container                       |
| Load Balancer      | AWS ALB                      | Routes HTTP traffic, performs health checks     |
| Networking         | VPC + public/private subnets | EC2 in private subnet, ALB in public            |
| CI/CD              | GitHub Actions               | Build → Test → Push → Deploy → Verify           |
| Deployment         | AWS SSM Run Command          | Agentless deploy, no port 22 needed             |
| IaC                | Terraform (modular)          | Reproducible, version-controlled infra          |
| Monitoring         | AWS CloudWatch               | Logs, metrics (CPU + memory), alarms, dashboard |

---

## Repository Structure

```
devops-challenge/
├── .github/
│   └── workflows/
│       └── deploy.yml        # GitHub Actions: Build → Test → Push → Deploy → Verify
│
├── app/
│   ├── src/index.js          # Express app: /, /health, /metrics
│   ├── tests/app.test.js     # Jest + supertest unit tests
│   ├── Dockerfile            # Multi-stage build (test in Stage 1, prod image in Stage 2)
│   └── package.json
│
├── terraform/
│   ├── modules/
│   │   ├── vpc/              # VPC, subnets, IGW, NAT gateways, route tables
│   │   ├── ecr/              # ECR repository + lifecycle policy
│   │   ├── alb/              # ALB, target group (instance type), listener, security group
│   │   ├── ec2/              # EC2 instance, IAM role, security group, target group attachment
│   │   └── monitoring/       # CloudWatch log group, alarms, dashboard
│   └── environments/
│       └── production/       # Wires all modules; holds backend config + tfvars
│
└── README.md
```

---

## Prerequisites

- AWS account with permissions to create VPC, EC2, ECR, ALB, CloudWatch, IAM, SSM resources
- [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.5
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured (`aws configure`)
- Docker (for local testing only)
- A GitHub repository to host this code

---

## Deployment Steps

### 1. Bootstrap Terraform Remote State (one-time)

```bash
aws s3api create-bucket \
    --bucket devops-challenge-tfstate-1 \
    --region us-east-1

aws s3api put-bucket-versioning \
    --bucket devops-challenge-tfstate-1 \
    --versioning-configuration Status=Enabled

aws dynamodb create-table \
    --table-name devops-challenge-tfstate-1-1-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region us-east-1
```

### 2. Deploy Infrastructure

```bash
cd terraform/environments/production

# Optional: set your email in terraform.tfvars to receive alarm notifications
# alert_email = "you@example.com"

terraform init
terraform plan
terraform apply
```

Note the three key outputs — you will need them in the next step:

```
app_url             = "http://<alb-dns-name>"
ecr_repository_url  = "<account>.dkr.ecr.us-east-1.amazonaws.com/devops-challenge"
ec2_instance_id     = "i-0abc123..."
```

### 3. Add GitHub Secrets

In your GitHub repository → **Settings → Secrets and variables → Actions**, add:

| Secret name             | Value                                                     |
| ----------------------- | --------------------------------------------------------- |
| `AWS_ACCESS_KEY_ID`     | IAM access key (needs ECR push + SSM send-command rights) |
| `AWS_SECRET_ACCESS_KEY` | Matching IAM secret key                                   |
| `EC2_INSTANCE_ID`       | From Terraform output: `i-0abc123...`                     |

**Minimum IAM permissions for the GitHub Actions user:**

```json
{
  "Effect": "Allow",
  "Action": [
    "ecr:GetAuthorizationToken",
    "ecr:BatchCheckLayerAvailability",
    "ecr:InitiateLayerUpload",
    "ecr:UploadLayerPart",
    "ecr:CompleteLayerUpload",
    "ecr:PutImage",
    "ssm:SendCommand",
    "ssm:GetCommandInvocation"
  ],
  "Resource": "*"
}
```

### 4. Push to `main` — Pipeline Runs Automatically

```bash
git add .
git commit -m "initial deploy"
git push origin main
```

GitHub Actions will:

1. **Build** the Docker image
2. **Test** — runs Jest tests inside the container
3. **Push** to ECR (tagged with git SHA + `latest`)
4. **Deploy** — sends an SSM Run Command to the EC2 instance: pull new image, stop old container, start new one
5. **Verify** — runs `curl /health` on the instance via SSM

### 5. Access the Application

```bash
APP_URL=$(cd terraform/environments/production && terraform output -raw app_url)
curl $APP_URL/health
# → {"healthy":true}

curl $APP_URL/metrics
# → {"uptime_seconds":42,"request_count":3,"memory_mb":28}
```

---

## CI/CD Pipeline Flow

```
git push to main
      │
      ▼
GitHub Actions triggered
      │
  ┌───▼────────────┐
  │   Checkout     │  actions/checkout@v4
  └───┬────────────┘
  ┌───▼────────────┐
  │   Build        │  docker build --target production
  └───┬────────────┘
  ┌───▼────────────┐
  │   Test         │  docker run --entrypoint npm ... test
  └───┬────────────┘
  ┌───▼────────────┐
  │ Push → ECR     │  :<git-sha> + :latest
  └───┬────────────┘
      │  (job: deploy, needs: build-and-push)
  ┌───▼────────────┐
  │ Deploy via SSM │  aws ssm send-command → docker pull + restart
  └───┬────────────┘
  ┌───▼────────────┐
  │ Verify health  │  ssm send-command → curl localhost:3000/health
  └───┬────────────┘
      ▼
  Pipeline green ✓
```

**Deployment is zero-downtime at the ALB level:** the ALB health check detects the new container is up before routing traffic, and the old container only stops after the new one is started.

---

## Monitoring

### Logs

- The CloudWatch Agent is installed on EC2 via user-data.
- Application logs written to `/var/log/devops-app.log` are streamed to CloudWatch Logs at `/ec2/devops-challenge`.
- Retention: **30 days**.

### Alarms

| Alarm                          | Metric                     | Threshold       | Action    |
| ------------------------------ | -------------------------- | --------------- | --------- |
| `devops-challenge-cpu-high`    | EC2 CPUUtilization         | > 80% for 2 min | SNS email |
| `devops-challenge-memory-high` | CWAgent mem_used_percent   | > 85% for 2 min | SNS email |
| `devops-challenge-alb-5xx`     | ALB HTTPCode_ELB_5XX_Count | > 10/min        | SNS email |

Set `alert_email` in `terraform.tfvars` and confirm the SNS subscription email to activate notifications.

### Dashboard

A CloudWatch Dashboard named `devops-challenge` is created automatically with widgets for:

- EC2 CPU utilization
- EC2 memory utilization (via CloudWatch Agent)
- ALB request count
- ALB 5xx errors
- Live log tail from `/ec2/devops-challenge`

---

## Design Decisions

### EC2 over ECS or EKS

EC2 gives full visibility into the runtime environment — you can SSH in, inspect Docker state, and troubleshoot directly. ECS Fargate abstracts the host away (useful in large teams), and EKS adds Kubernetes overhead that is disproportionate for a single service. For a team comfortable with EC2, it is the most transparent and debuggable option.

### GitHub Actions over Jenkins

GitHub Actions is natively integrated with the repository — no separate server to provision or maintain. Secrets are stored securely in GitHub, and the YAML workflow lives alongside the code. Jenkins is preferred in air-gapped or enterprise environments; here, GitHub Actions gives the same pipeline capability with less operational overhead.

### SSM Run Command for deployments (no port 22)

Rather than storing an SSH private key as a secret and exposing port 22, the EC2 instance registers with SSM via its IAM role. GitHub Actions calls `aws ssm send-command` to execute the deployment script. Port 22 is never opened, and there is no long-lived credential on the server.

### EC2 in a private subnet

The EC2 instance has no public IP. All inbound traffic arrives via the ALB (public subnets). Outbound internet access goes through NAT gateways. SSM traffic uses the SSM endpoint over AWS internal networks.

### Multi-stage Dockerfile

Stage 1 installs all dependencies and runs Jest tests — if tests fail the image is not produced. Stage 2 copies only the production dependency tree and source, runs as a non-root user (`appuser`), resulting in a minimal, hardened image.

### Terraform modules

Each module (vpc, ecr, alb, ec2, monitoring) owns its resources independently. The `environments/production/` directory composes them. Adding a staging environment means duplicating only `environments/` — not the modules.

---

## Assumptions

- A single AWS region (`us-east-1`) is sufficient for this assessment.
- HTTP (port 80) is used; HTTPS/TLS is a noted improvement.
- The EC2 instance is a single node — no auto-scaling group. Noted as an improvement.
- The first `terraform apply` provisions the EC2 instance; the first `git push` to `main` deploys the application.

---

## Limitations & Improvements

| Area              | Current state                 | Improvement                                                  |
| ----------------- | ----------------------------- | ------------------------------------------------------------ |
| TLS               | HTTP only                     | Add ACM certificate + HTTPS listener on ALB                  |
| High availability | Single EC2 instance           | Replace with an Auto Scaling Group (min 2) behind the ALB    |
| Secrets           | Env vars passed inline        | Use AWS Secrets Manager with Docker `--env-file` from SSM    |
| Multi-environment | Production only               | Add `environments/staging/` with `t3.micro`                  |
| DNS               | ALB-generated hostname        | Route53 record + custom domain                               |
| Image scanning    | ECR scan on push              | Gate pipeline on scan results (fail on HIGH/CRITICAL CVEs)   |
| State bucket      | Created manually              | Bootstrap with a separate `terraform/bootstrap/` module      |
| Rollback          | Manual re-run of previous SHA | Store previous image tag; add a rollback job to the workflow |
