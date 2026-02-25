# 🔒 Secure CI/CD Pipeline — ECS + SAST/SCA

[![Jenkins](https://img.shields.io/badge/Jenkins-LTS-red)](https://www.jenkins.io/)
[![Docker](https://img.shields.io/badge/Docker-20.10+-blue)](https://www.docker.com/)
[![Node.js](https://img.shields.io/badge/Node.js-18+-green)](https://nodejs.org/)
[![AWS](https://img.shields.io/badge/AWS-ECR%20%2B%20ECS-orange)](https://aws.amazon.com/)
[![Security](https://img.shields.io/badge/Security-SAST%20%7C%20SCA%20%7C%20Trivy%20%7C%20Gitleaks-purple)](https://owasp.org/)

> **A hardened CI/CD pipeline** that automatically tests, scans for vulnerabilities, and deploys a Node.js app to **Amazon ECS (Fargate)**. If any **Critical or High** security issues are found, the pipeline **blocks the deployment** automatically.

---

## 📖 Table of Contents

1. [What Is This Project?](#-what-is-this-project)
2. [How Does It Work? (The Big Picture)](#-how-does-it-work-the-big-picture)
3. [Architecture Diagram](#-architecture-diagram)
4. [Project Files Explained](#-project-files-explained)
5. [Key Concepts for Beginners](#-key-concepts-for-beginners)
6. [Prerequisites — What You Need Before Starting](#-prerequisites--what-you-need-before-starting)
7. [Step 1: Run the App Locally (Try This First!)](#-step-1-run-the-app-locally-try-this-first)
8. [Step 2: Run with Docker Locally](#-step-2-run-with-docker-locally)
9. [Step 3: Set Up AWS (ECR + ECS)](#-step-3-set-up-aws-ecr--ecs)
10. [Step 4: Set Up Jenkins](#-step-4-set-up-jenkins)
11. [Step 5: Run the Pipeline](#-step-5-run-the-pipeline)
12. [Step 6: Test the Security Gate (Fail then Pass)](#-step-6-test-the-security-gate-fail-then-pass)
13. [Pipeline Stages Explained (All 19 Steps)](#-pipeline-stages-explained-all-19-steps)
14. [Security Scans Explained](#-security-scans-explained)
15. [Reports and Artifacts](#-reports-and-artifacts)
16. [Jenkins Parameters Reference](#-jenkins-parameters-reference)
17. [AWS IAM Permissions Required](#-aws-iam-permissions-required)
18. [CloudWatch Logging & Monitoring](#-cloudwatch-logging--monitoring)
19. [Cleanup Guide](#-cleanup-guide)
20. [Troubleshooting (Common Errors)](#-troubleshooting-common-errors)
21. [Recent Updates & Engineering Challenges](#-recent-updates--engineering-challenges)
22. [Makefile Commands (Quick Reference)](#-makefile-commands-quick-reference)
23. [Frequently Asked Questions (FAQ)](#-frequently-asked-questions-faq)
24. [Documentation Links](#-documentation-links)

---

## 🤔 What Is This Project?

This project is a **secure, automated deployment pipeline**. Here's what that means in plain English:

| Term | What it means |
|------|---------------|
| **CI/CD** | Continuous Integration / Continuous Deployment — every time you push code, it automatically tests, scans, builds, and deploys your app |
| **Pipeline** | A sequence of automated steps that your code goes through (like an assembly line in a factory) |
| **Security Gate** | A checkpoint that **blocks deployment** if vulnerabilities are found |
| **ECS** | Amazon Elastic Container Service — runs your Docker container in the cloud |
| **ECR** | Amazon Elastic Container Registry — stores your Docker images (like Docker Hub, but on AWS) |
| **Fargate** | A serverless way to run containers on AWS (you don't manage servers) |

### What the app does

The app itself is simple — a Node.js/Express web server with three endpoints:

| Endpoint | What it returns |
|----------|-----------------|
| `GET /` | An HTML page saying "CI/CD Pipeline App" with version info |
| `GET /health` | `{ "status": "healthy" }` — used by AWS to check if the app is alive |
| `GET /api/info` | `{ "version": "...", "deploymentTime": "...", "status": "running" }` |

**The real value** of this project is the **pipeline** that builds, scans, and deploys this app securely.

---

## 🔄 How Does It Work? (The Big Picture)

```
YOU push code to Git
        │
        ▼
┌─────────────────┐
│    JENKINS       │ ← Detects the push and starts the pipeline
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────────────────────┐
│                    PIPELINE STAGES                   │
│                                                      │
│  1. 📥 Checkout code from Git                       │
│  2. ✅ Validate required AWS parameters              │
│  3. 🏷️  Generate build version tag                   │
│  4. 📦 Install npm dependencies                      │
│  5. 🧪 Run unit tests                               │
│  6. 🔍 SAST scan (SonarQube — code quality)         │
│  7. ⏳ Wait for SonarQube quality gate               │
│  8. 🔐 Secret scan (Gitleaks — find leaked secrets)  │
│  9. 📋 SCA scan (npm audit — prod dependencies)      │
│ 10. 📜 Generate SBOM (Software Bill of Materials)    │
│ 11. 🐳 Build Docker image                            │
│ 12. 🛡️  Image scan (Trivy — container vulnerabilities)│
│ 13. 🚨 SECURITY GATE — blocks if issues found!      │
│ 14. 📤 Push image to AWS ECR                         │
│ 15. ♻️  Apply ECR lifecycle policy (cleanup old images)│
│ 16. 📝 Render ECS task definition                    │
│ 17. 📋 Register new task definition revision in ECS  │
│ 18. 🚀 Deploy to ECS service (rolling update)        │
│ 19. 🧹 Cleanup old ECS task definition revisions     │
└─────────────────────────────────────────────────────┘
         │
         ▼
  ✅ App is live on AWS ECS!
  (or ❌ Blocked if vulnerabilities found)
```

---

## 🏗️ Architecture Diagram

```
┌──────────────┐       ┌──────────────────┐       ┌──────────────────────┐
│   Developer  │──────▶│   Git Repository  │──────▶│     Jenkins Server   │
│  (Your Mac)  │ push  │   (GitHub, etc.)  │ hook  │   (EC2 or Docker)    │
└──────────────┘       └──────────────────┘       └──────────┬───────────┘
                                                              │
                        ┌─────────────────────────────────────┼─────────────────────┐
                        │              Jenkins Pipeline       │                     │
                        │                                     ▼                     │
                        │  ┌────────┐  ┌──────────┐  ┌──────────────┐              │
                        │  │ Tests  │  │ Security │  │  Docker      │              │
                        │  │ (Jest) │  │ Scans    │  │  Build       │              │
                        │  └────────┘  │          │  └──────┬───────┘              │
                        │              │ SonarQube│         │                       │
                        │              │ Gitleaks │         │                       │
                        │              │ npm audit│   ┌─────▼─────┐                │
                        │              │ Trivy    │   │ Trivy Scan │                │
                        │              │ Syft     │   └─────▼─────┘                │
                        │              └──────────┘         │                       │
                        │                    │              │                       │
                        │              ┌─────▼──────────────▼─────┐                │
                        │              │    🚨 SECURITY GATE 🚨   │                │
                        │              │ Blocks on CRITICAL/HIGH   │                │
                        │              └─────────────┬────────────┘                │
                        │                            │ PASS                        │
                        └────────────────────────────┼────────────────────────────┘
                                                     │
                                                     ▼
                              ┌──────────────────────────────────────┐
                              │           AWS Cloud                   │
                              │                                       │
                              │  ┌─────────┐      ┌───────────────┐  │
                              │  │   ECR   │      │   ECS Cluster  │  │
                              │  │ (Image  │─────▶│   (Fargate)    │  │
                              │  │  Store) │      │                │  │
                              │  └─────────┘      │  ┌───────────┐ │  │
                              │                   │  │ Container │ │  │
                              │  ┌────────────┐   │  │  (app.js) │ │  │
                              │  │ CloudWatch │◀──│  └───────────┘ │  │
                              │  │   Logs     │   └───────────────┘  │
                              │  └────────────┘                       │
                              └──────────────────────────────────────┘
```

---

## 📁 Project Files Explained

Here's what every file and folder does — read this to understand the project:

### Root Files

| File | What it does | You need to touch it? |
|------|-------------|----------------------|
| `app.js` | The Node.js web server (Express). This is the actual app being deployed. | Only if you want to change the app |
| `app.test.js` | Unit tests for `app.js`. Uses Jest + Supertest. | Only if you add new endpoints |
| `Jenkinsfile` | **The pipeline definition.** All 19 stages are here. Jenkins reads this file. | When you need to customize the pipeline |
| `Dockerfile` | Instructions to build the Docker container image for the app. | Rarely |
| `docker-compose.yml` | Lets you run the app locally with `docker compose up`. | Rarely |
| `package.json` | Node.js project config — lists dependencies and scripts. | When adding packages |
| `Makefile` | Shortcuts for common commands (`make install`, `make test`, etc.) | Never (just use it) |
| `sonar-project.properties` | Config for SonarQube code analysis. | Only if your SonarQube setup differs |
| `.gitignore` | Files/folders Git should ignore. | Rarely |
| `RUNBOOK.md` | Operational runbook with quick-start and troubleshooting. | Read it for reference |
| `collect-evidence.sh` | Script to collect logs/evidence for project submission. | Run it when collecting evidence |

### `ecs/` — ECS Configuration Files

| File | What it does |
|------|-------------|
| `taskdef.template.json` | ECS task definition **template** with `__PLACEHOLDERS__`. The pipeline fills in real values at build time. |
| `taskdef.rendered.example.json` | An **example** of what the filled-in task definition looks like. For reference only. |
| `ecr-lifecycle-policy.json` | Tells ECR to automatically delete old images (untagged after 7 days, keep max 20 tagged). |

### `scripts/` — Pipeline Helper Scripts

| File | What it does |
|------|-------------|
| `security-gate.js` | **The security gate.** Reads npm audit, Trivy, and Gitleaks reports. Exits with error if Critical/High vulns or secrets found. This is what blocks bad deployments! |
| `render-ecs-taskdef.sh` | Replaces `__PLACEHOLDERS__` in the task definition template with actual values (image URI, role ARNs, etc.) |
| `cleanup-ecs-revisions.sh` | Deletes old ECS task definition revisions, keeping only the most recent N. |
| `inject-vulnerable-dependency.sh` | **Test script:** adds a known-vulnerable `lodash@4.17.11` to simulate a security failure. |
| `remove-vulnerable-dependency.sh` | **Test script:** removes the vulnerable dependency to simulate a fix. |

### `reports/` — Generated by Pipeline

This folder is populated when Jenkins runs. It contains:
- `reports/sca/` — npm audit results
- `reports/image/` — Trivy container scan results
- `reports/secret/` — Gitleaks secret scan results
- `reports/sbom/` — Software Bill of Materials (CycloneDX format)
- `reports/deploy/` — ECS deployment evidence (task definition, service status)

### `docs/` and `evidence/`

| Folder | What it contains |
|--------|-----------------|
| `docs/SECURE-CICD-ECS.md` | Detailed guide for the secure pipeline setup and validation |
| `evidence/README.md` | Checklist of evidence to collect for project submission |

### `terraform/` — Infrastructure as Code

Terraform provisions **ALL** AWS infrastructure automatically. Run `terraform apply` once and everything is ready.

| Module | What it creates |
|--------|---------------|
| `modules/vpc` | VPC, subnets, route tables, internet gateway |
| `modules/ecr` | ECR repository + lifecycle policy |
| `modules/ecs` | ECS cluster, service, task definition, IAM roles, security group, CloudWatch logs + alarms |
| `modules/iam` | Jenkins IAM role with ECR push/pull, ECS deploy, CloudWatch, and PassRole permissions |
| `modules/security` | Security groups for Jenkins and app server |
| `modules/jenkins` | Jenkins EC2 instance with Docker + AWS CLI pre-installed |
| `modules/monitoring` | CloudWatch alarms and VPC flow logs |
| `modules/secrets` | AWS Secrets Manager for Jenkins password and SSH keys |
| `modules/keypair` | Auto-generated SSH key pair |
| `modules/vpc-endpoints` | VPC endpoints for private AWS API access |

---

## 📚 Key Concepts for Beginners

If these terms are new to you, read this section first:

### What is Docker?
Docker packages your app and all its dependencies into a **container** — a lightweight, portable unit that runs the same everywhere. Think of it as a "box" that contains your app + everything it needs.

### What is a Docker Image vs Container?
- **Image** = the blueprint/recipe (like a class in programming)
- **Container** = a running instance of that image (like an object)

### What is ECR (Elastic Container Registry)?
It's like Docker Hub, but hosted on your AWS account. Your pipeline pushes Docker images here. ECR stores them privately.

### What is ECS (Elastic Container Service)?
ECS runs your Docker containers in the cloud. With **Fargate**, you don't manage any servers — AWS handles the infrastructure.

### What is a Task Definition?
An ECS task definition tells ECS: "Here's how to run my container — use this image, this much CPU/memory, these environment variables, and send logs here."

### What is Jenkins?
Jenkins is a server that watches your Git repository. When you push code, it automatically runs the pipeline (test → scan → build → deploy).

### What is SAST?
**Static Application Security Testing** — scans your source code for bugs, code smells, and security issues WITHOUT running the app. Tool used: **SonarQube**.

### What is SCA?
**Software Composition Analysis** — checks your production dependencies (npm packages) for known vulnerabilities. Tool used: **npm audit**.

### What is a Container Image Scan?
Scans the built Docker image for OS-level and package vulnerabilities inside the container. Tool used: **Trivy**.

### What is Secret Scanning?
Scans your code repository for accidentally committed secrets (API keys, passwords, tokens). Tool used: **Gitleaks**.

### What is an SBOM?
**Software Bill of Materials** — a complete list of every component/library in your app. Like an "ingredients list" for software. Tool used: **Syft** (CycloneDX format).

### What is a Security Gate?
A checkpoint in the pipeline that reads all scan results and **blocks deployment** if anything critical is found. Implemented in `scripts/security-gate.js`.

---

## ✅ Prerequisites — What You Need Before Starting

### For Running Locally (Minimum)

| Tool | Version | How to install on Mac | Verify |
|------|---------|----------------------|--------|
| **Node.js** | 18+ | `brew install node@18` | `node --version` |
| **npm** | 9+ | Comes with Node.js | `npm --version` |
| **Git** | Any | `brew install git` | `git --version` |

### For Running with Docker (Recommended)

| Tool | Version | How to install on Mac | Verify |
|------|---------|----------------------|--------|
| **Docker Desktop** | 20.10+ | [Download here](https://www.docker.com/products/docker-desktop/) | `docker --version` |

### For Full Pipeline (Jenkins + AWS)

| Tool | Version | How to install/get | Verify |
|------|---------|-------------------|--------|
| **AWS Account** | — | [Sign up](https://aws.amazon.com/) | Log in to AWS Console |
| **AWS CLI** | v2 | `brew install awscli` | `aws --version` |
| **Jenkins** | LTS | Run via Docker (see below) | Access at `http://<jenkins-ip>:8080` |
| **AWS IAM User** | — | Create in AWS Console (see IAM section below) | `aws sts get-caller-identity` |

### AWS CLI Configuration

After installing the AWS CLI, configure it with your credentials:

```bash
aws configure
# It will prompt you for:
#   AWS Access Key ID:     <your-access-key>
#   AWS Secret Access Key: <your-secret-key>
#   Default region name:   eu-central-1        (or your preferred region)
#   Default output format: json
```

> ⚠️ **Never commit your AWS credentials to Git!** The `.gitignore` already excludes `.env` files.

---

## 🚀 Step 1: Run the App Locally (Try This First!)

Start here to make sure the basic app works before worrying about pipelines.

### 1.1 Clone the repository

```bash
git clone https://github.com/<your-username>/Gitops_lab.git
cd Gitops_lab
```

### 1.2 Install dependencies

```bash
npm ci
```

> `npm ci` is like `npm install` but faster and more reliable (it uses the exact versions from `package-lock.json`).

### 1.3 Run the tests

```bash
npm test
```

You should see output like:
```
 PASS  ./app.test.js
  App Tests
    ✓ GET / should return HTML page
    ✓ GET /health should return healthy status  
    ✓ GET /api/info should return app info

Test Suites: 1 passed, 1 total
Tests:       3 passed, 3 total
```

### 1.4 Start the app

```bash
npm start
```

You should see:
```
Server running on port 5000
```

### 1.5 Test the endpoints (open a NEW terminal tab)

```bash
# Health check
curl http://localhost:5000/health
# Expected: {"status":"healthy"}

# App info
curl http://localhost:5000/api/info
# Expected: {"version":"1.0.0","deploymentTime":"...","status":"running"}

# Main page (opens HTML)
curl http://localhost:5000/
# Expected: HTML page with "CI/CD Pipeline App"
```

### 1.6 Stop the app

Press `Ctrl + C` in the terminal where the app is running.

### Or use the Makefile shortcuts

```bash
make install   # same as npm ci
make test      # same as npm test
make run       # same as npm start
```

---

## 🐳 Step 2: Run with Docker Locally

This builds and runs the same Docker image that the pipeline would create.

### 2.1 Build the image

```bash
docker build -t cicd-node-app:local .
```

### 2.2 Run the container

```bash
docker run --rm -p 5000:5000 --name cicd-node-app-local cicd-node-app:local
```

### 2.3 Test it

```bash
curl http://localhost:5000/health
curl http://localhost:5000/api/info
```

### 2.4 Stop it

Press `Ctrl + C` or run:
```bash
docker stop cicd-node-app-local
```

### Alternative: Use Docker Compose

```bash
docker compose up --build      # start
docker compose down            # stop
```

---

## ☁️ Step 3: Set Up ALL AWS Infrastructure with Terraform

> ⚠️ **This costs money!** AWS charges for ECS (Fargate), ECR storage, CloudWatch, etc. Use the [AWS Free Tier](https://aws.amazon.com/free/) where possible and **clean up when done** (see [Cleanup Guide](#-cleanup-guide)).

**Terraform creates EVERYTHING for you automatically:**
- ✅ VPC with public/private subnets and routing
- ✅ ECR repository (Docker image storage) with lifecycle policy
- ✅ ECS Cluster (Fargate) with service and task definition
- ✅ IAM roles (ECS execution role, task role, Jenkins role with ECR/ECS permissions)
- ✅ Security groups (Jenkins, app server, ECS tasks)
- ✅ CloudWatch log groups for ECS container logs
- ✅ CloudWatch alarms for CPU/memory monitoring
- ✅ Jenkins EC2 instance with Docker + AWS CLI
- ✅ VPC flow logs and secrets management

### 3.1 Install Terraform (if not already installed)

```bash
# On Mac:
brew install terraform

# Verify:
terraform --version
```

### 3.2 Configure your variables

```bash
cd terraform
```

Edit `terraform.tfvars` with your values. The most important things to change:

```hcl
# Get your IP address first:
# curl ifconfig.me

# Then update these in terraform.tfvars:
allowed_ips     = ["YOUR_ACTUAL_IP/32"]    # Replace with your real IP
app_allowed_ips = ["YOUR_ACTUAL_IP/32"]    # Replace with your real IP
jenkins_admin_password = "YourStrongPassword123!"  # Change this!
```

> 💡 **Tip:** Run `curl ifconfig.me` to get your public IP address, then put it in the **allowed_ips** fields.

All ECR and ECS variables have sensible defaults that match the Jenkinsfile — you don't need to change them unless you want different names.

### 3.3 Initialize Terraform

```bash
terraform init
```

This downloads the AWS provider and sets up the modules.

### 3.4 Preview what will be created

```bash
terraform plan
```

This shows you everything Terraform will create **without actually creating it**. Review the output to make sure it looks right.

### 3.5 Apply (create everything!)

```bash
terraform apply
```

Terraform will ask: `Do you want to perform these actions?` Type **`yes`** and press Enter.

**This takes 3-5 minutes.** When it finishes, you'll see all the outputs, including a special **jenkins_pipeline_parameters** block:

```
╔════════════════════════════════════════════════════════════╗
║        JENKINS PIPELINE PARAMETERS (copy these!)         ║
╠════════════════════════════════════════════════════════════╣
║                                                          ║
║  AWS_REGION             = eu-central-1
║  AWS_ACCOUNT_ID         = 123456789012
║  ECR_REPOSITORY         = cicd-node-app
║  ECS_CLUSTER            = cicd-node-cluster
║  ECS_SERVICE            = cicd-node-service
║  ECS_TASK_FAMILY        = cicd-node-app
║  ECS_EXECUTION_ROLE_ARN = arn:aws:iam::123456789012:role/...
║  ECS_TASK_ROLE_ARN      = arn:aws:iam::123456789012:role/...
║  CLOUDWATCH_LOG_GROUP   = /ecs/cicd-node-app
║                                                          ║
╚════════════════════════════════════════════════════════════╝
```

> 🎯 **Copy these values!** You'll paste them into Jenkins when running the pipeline.

### 3.6 View outputs anytime

If you need to see the outputs again later:

```bash
cd terraform
terraform output

# Get a specific value:
terraform output jenkins_url
terraform output ecs_task_execution_role_arn
terraform output jenkins_pipeline_parameters
```

### What Terraform Created (Summary)

| Resource | Terraform Module | What it does |
|----------|-----------------|-------------|
| VPC + Subnets | `modules/vpc` | Network isolation for all resources |
| ECR Repository | `modules/ecr` | Stores Docker images with auto-cleanup lifecycle policy |
| ECS Cluster | `modules/ecs` | Fargate cluster to run containers |
| ECS Service | `modules/ecs` | Keeps 1 container running, handles rolling deployments |
| ECS Task Definition | `modules/ecs` | Initial container config (Jenkins updates this on each deploy) |
| ECS Execution Role | `modules/ecs` | Lets ECS pull images from ECR and write to CloudWatch |
| ECS Task Role | `modules/ecs` | Permissions for the app container itself |
| ECS Security Group | `modules/ecs` | Allows port 5000 inbound from your IP |
| Jenkins IAM Role | `modules/iam` | ECR push/pull, ECS register/update, CloudWatch, PassRole |
| CloudWatch Log Group | `modules/ecs` | `/ecs/cicd-node-app` — receives container stdout/stderr |
| CloudWatch Alarms | `modules/ecs` | CPU and memory alerts at 80% threshold |
| Jenkins EC2 | `modules/jenkins` | CI/CD server with Docker access |

---

## 🔧 Step 4: Set Up Jenkins

> 💡 **Terraform already created your Jenkins EC2 instance in Step 3!** You just need to access it and configure the pipeline.

### 4.1 Access Jenkins

Get the Jenkins URL from Terraform:

```bash
cd terraform
terraform output jenkins_url
# Example output: http://3.120.45.67:8080
```

Open that URL in your browser.

### 4.2 Get the Initial Admin Password

SSH into the Jenkins server and retrieve the password:

```bash
# Get the SSH command from Terraform
terraform output ssh_jenkins
# Example: ssh -i ./cicd-pipeline-dev-keypair2.pem ec2-user@3.120.45.67

# After SSHing in:
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Or if you set `jenkins_admin_password` in `terraform.tfvars`, use that.


### 4.3 Install Required Plugins

Go to **Manage Jenkins → Plugins → Available** and install:

- ✅ Pipeline
- ✅ Git
- ✅ Docker Pipeline
- ✅ SonarQube Scanner (if using SonarQube)
- ✅ JUnit
- ✅ Timestamper

### 4.4 Configure AWS Credentials

Go to **Manage Jenkins → Credentials → System → Global → Add Credentials**

Choose **AWS Credentials** or **Secret text** and add:
- Your `AWS_ACCESS_KEY_ID`
- Your `AWS_SECRET_ACCESS_KEY`

> Alternatively, attach an IAM Instance Profile to the Jenkins EC2 instance (more secure, no keys needed).

### 4.5 Configure SonarQube (Optional)

If you want to use the SAST scan:

1. Go to **Manage Jenkins → Configure System → SonarQube servers**
2. Add a server:
   - Name: `sonarqube` (must match the `SONARQUBE_SERVER` parameter)
   - Server URL: `http://<sonarqube-ip>:9000`
   - Authentication token: create one in SonarQube and add it here

> If you don't have SonarQube, leave `ENABLE_SONARQUBE` as `false` — the pipeline will skip it.

### 4.6 Create the Pipeline Job

1. Jenkins Dashboard → **New Item**
2. Name: `Secure-CICD-Pipeline`
3. Type: **Pipeline** → OK
4. Under **Pipeline** section:
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `https://github.com/<your-username>/Gitops_lab.git`
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`
5. Check **"This project is parameterized"** (the parameters are defined in the Jenkinsfile, but Jenkins needs to populate them on first run)
6. **Save**

---

## ▶️ Step 5: Run the Pipeline

### 5.1 Trigger a Build

1. Go to your Jenkins job
2. Click **"Build with Parameters"**
3. Fill in the required fields:

| Parameter | What to put | Example |
|-----------|-------------|---------|
| `AWS_REGION` | Your AWS region | `eu-central-1` |
| `AWS_ACCOUNT_ID` | Your 12-digit AWS account ID | `123456789012` |
| `ECR_REPOSITORY` | ECR repo name | `cicd-node-app` |
| `ECS_CLUSTER` | ECS cluster name | `cicd-node-cluster` |
| `ECS_SERVICE` | ECS service name | `cicd-node-service` |
| `ECS_TASK_FAMILY` | Task definition family | `cicd-node-app` |
| `ECS_EXECUTION_ROLE_ARN` | Full ARN of execution role | `arn:aws:iam::123456789012:role/ecsTaskExecutionRole` |
| `ECS_TASK_ROLE_ARN` | Full ARN of task role | `arn:aws:iam::123456789012:role/cicd-node-app-task-role` |
| `CLOUDWATCH_LOG_GROUP` | CloudWatch log group name | `/ecs/cicd-node-app` |
| `ENABLE_SONARQUBE` | Enable SonarQube scan? | `false` (unless you have it set up) |

4. Click **"Build"**

### 5.2 Monitor the Build

- Click on the build number (e.g., `#1`)
- Click **"Console Output"** to see live logs
- Watch each stage complete (or fail)

### 5.3 What Success Looks Like

```
[Pipeline] stage
[Pipeline] { (Security Gate)
Security gate passed. No Critical/High vulnerabilities and no secrets detected.
...
[Pipeline] { (Deploy to ECS Service)
...
Secure CI/CD pipeline completed and ECS service updated.
Finished: SUCCESS
```

---

## 🧪 Step 6: Test the Security Gate (Fail then Pass)

This is a **required validation** — you need to prove the security gate works.

### 6.1 Inject a Vulnerable Dependency (Make It FAIL)

```bash
# This adds lodash@4.17.11, which has known Critical/High vulnerabilities
bash scripts/inject-vulnerable-dependency.sh

# Commit and push the change
git add package.json package-lock.json
git commit -m "test: inject vulnerable dependency for gate validation"
git push
```

**Trigger a Jenkins build.** Expected result:
- ❌ The **Security Gate** stage FAILS
- ❌ The pipeline STOPS — no deployment happens
- Console output shows: `Security gate failed. Critical/High vulnerabilities or secrets were detected.`

**Save evidence:**
- Screenshot of the failed Jenkins build
- The failed security report from `reports/sca/`

### 6.2 Remove the Vulnerable Dependency (Make It PASS)

```bash
# This removes the vulnerable lodash
bash scripts/remove-vulnerable-dependency.sh

# Commit and push the fix
git add package.json package-lock.json
git commit -m "fix: remove vulnerable dependency - gate should pass"
git push
```

**Trigger another Jenkins build.** Expected result:
- ✅ The **Security Gate** stage PASSES
- ✅ The pipeline continues to ECR push and ECS deployment
- Console output shows: `Security gate passed. No Critical/High vulnerabilities and no secrets detected.`

**Save evidence:**
- Screenshot of the successful Jenkins build
- All reports from `reports/`

---

## 📋 Pipeline Stages Explained (All 19 Steps)

Here's what happens at each stage, in order:

| # | Stage | What happens | Can it fail the build? |
|---|-------|-------------|----------------------|
| 1 | **Checkout** | Clones your code from Git, creates `reports/` directories | Rarely |
| 1.1 | **Lint Dockerfile** | Uses Hadolint to check for container best practices | Yes |
| 1.2 | **Lint Scripts** | Uses ShellCheck to validate deployment shell scripts | Yes |
| 2 | **Validate Required Inputs** | Checks that `AWS_ACCOUNT_ID`, `ECS_EXECUTION_ROLE_ARN`, and `ECS_TASK_ROLE_ARN` are filled in | Yes, if you forget to fill them |
| 3 | **Build Metadata** | Generates version tags like `build-42-a1b2c3d4` using build number + git SHA | No |
| 4 | **Install** | Runs `npm ci` inside a Node.js Docker container | Yes, if `package.json` is broken |
| 5 | **Unit Tests** | Runs `npm test` with coverage | Yes, if tests fail |
| 6 | **SAST - SonarQube** | Runs SonarQube static analysis (skipped if `ENABLE_SONARQUBE=false`) | Yes, if code quality too low |
| 7 | **SAST Quality Gate** | Waits for SonarQube to finish analysis | Yes, if SonarQube quality gate fails |
| 8 | **Secret Scan - Gitleaks** | Scans repo for accidentally committed secrets/keys/passwords | No (writes report, gate checks later) |
| 9 | **SCA - npm audit** | Scans production dependencies for known CVEs using `npm audit --omit=dev` | No (writes report, gate checks later) |
| 10 | **SBOM - Syft** | Generates a complete list of all software components in CycloneDX format | Rarely |
| 11 | **Build Container** | Runs `docker build`, creates the production Docker image | Yes, if Dockerfile is broken |
| 12 | **Image Scan - Trivy** | Scans the Docker image for OS-level and library vulnerabilities | No (writes report, gate checks later) |
| 13 | **Security Gate** | 🚨 **THE KEY STAGE.** Runs `scripts/security-gate.js` which reads npm audit, Trivy, and Gitleaks reports. Fails if ANY Critical/High vuln or secret is found. | **YES — this is the main blocker** |
| 14 | **ECR Login and Push** | Logs in to ECR, tags image with `build-*`, `sha-*`, `latest`, and pushes all three tags | Yes, if AWS auth fails |
| 15 | **Apply ECR Lifecycle** | Applies `ecs/ecr-lifecycle-policy.json` to auto-delete old images | Rarely |
| 16 | **Render ECS Task Definition** | Runs `scripts/render-ecs-taskdef.sh` to fill in `__PLACEHOLDERS__` in the template with real values | Yes, if env vars are missing |
| 17 | **Register ECS Task Definition** | Registers the rendered JSON as a new task definition revision in AWS ECS | Yes, if JSON is invalid or permissions fail |
| 18 | **Deploy to ECS Service** | Updates the ECS service to use the new task definition, waits for the service to be stable | Yes, if container fails to start |
| 19 | **Cleanup Old ECS Revisions** | Deregisters old task definition revisions (keeps latest 10 by default) | Rarely |

---

## 🔍 Security Scans Explained

| Scan Type | Tool | What It Checks | Report Location | Blocks Deployment? |
|-----------|------|---------------|-----------------|-------------------|
| **SAST** | SonarQube | Source code for bugs, code smells, security hotspots | SonarQube Dashboard | Yes (via Quality Gate) |
| **SCA** | npm audit | production dependencies for known CVEs | `reports/sca/npm-audit-report.json` | Yes (via Security Gate) |
| **Image Scan** | Trivy | Docker image for OS/package vulnerabilities | `reports/image/trivy-image.json` | Yes (via Security Gate) |
| **Secret Scan** | Gitleaks | Git history for API keys, passwords, tokens | `reports/secret/gitleaks-report.json` | Yes (via Security Gate) |
| **SBOM** | Syft | Generates inventory of all components | `reports/sbom/sbom-cyclonedx.json` | No (informational) |

### How the Security Gate Decides

The logic is in `scripts/security-gate.js`:

1. Reads SCA report → counts CRITICAL and HIGH vulnerabilities
2. Reads Trivy report → counts CRITICAL and HIGH vulnerabilities
3. Reads Gitleaks report → counts number of secrets found
4. **If ANY of these counts > 0 → EXIT 1 (FAIL)**
5. If all counts are 0 → EXIT 0 (PASS)

---

## 📊 Reports and Artifacts

After a pipeline run, these files are created and archived in Jenkins:

| Report | Location | Format | Description |
|--------|----------|--------|-------------|
| SCA Report | `reports/sca/npm-audit-report.json` | JSON | Detailed dependency vulnerability data |
| Image Scan | `reports/image/trivy-image.json` | JSON | Container image vulnerability findings |
| Secret Scan | `reports/secret/gitleaks-report.json` | JSON | Any secrets found in the codebase |
| SBOM | `reports/sbom/sbom-cyclonedx.json` | CycloneDX JSON | Complete software bill of materials |
| Rendered Task Def | `reports/deploy/taskdef.rendered.json` | JSON | The actual ECS task definition that was registered |
| Task Def ARN | `reports/deploy/taskdef-arn.txt` | Text | The ARN of the registered task definition |
| ECS Update | `reports/deploy/ecs-update-service.json` | JSON | Response from ECS service update |
| ECS Status | `reports/deploy/ecs-service-status.json` | JSON | Final ECS service state after deployment |
| Image URI | `reports/deploy/image-uri.txt` | Text | The full ECR image URI that was deployed |

---

## ⚙️ Jenkins Parameters Reference

These parameters are defined at the top of the `Jenkinsfile` and can be changed per build:

| Parameter | Default | Required? | Description |
|-----------|---------|-----------|-------------|
| `AWS_REGION` | `eu-central-1` | Yes | AWS region where ECR and ECS are hosted |
| `AWS_ACCOUNT_ID` | *(empty)* | **Yes** | Your 12-digit AWS account ID (e.g., `123456789012`) |
| `ECR_REPOSITORY` | `cicd-node-app` | Yes | Name of the ECR repository to push images to |
| `ECS_CLUSTER` | `cicd-node-cluster` | Yes | Name of your ECS cluster |
| `ECS_SERVICE` | `cicd-node-service` | Yes | Name of your ECS service |
| `ECS_TASK_FAMILY` | `cicd-node-app` | Yes | ECS task definition family name |
| `ECS_EXECUTION_ROLE_ARN` | *(empty)* | **Yes** | Full ARN of the ECS task execution role |
| `ECS_TASK_ROLE_ARN` | *(empty)* | **Yes** | Full ARN of the ECS task role |
| `CLOUDWATCH_LOG_GROUP` | `/ecs/cicd-node-app` | Yes | CloudWatch log group for container logs |
| `ENABLE_SONARQUBE` | `false` | No | Set to `true` only if you have SonarQube configured |
| `SONARQUBE_SERVER` | `sonarqube` | No | Jenkins SonarQube configuration name |
| `GITLEAKS_IMAGE` | `ghcr.io/gitleaks/gitleaks:latest` | No | Docker image used for secret scanning |
| `DEPLOYMENT_STRATEGY` | `rolling` | Yes | Only `rolling` is implemented |
| `APPLY_ECR_LIFECYCLE_POLICY` | `true` | No | Whether to apply the ECR cleanup policy |
| `KEEP_ECS_REVISIONS` | `10` | No | How many old task definition revisions to keep |

---

## 🔐 AWS IAM Permissions Required

> 💡 **Terraform creates all of these automatically!** The `modules/iam` and `modules/ecs` Terraform modules set up Jenkins IAM roles with ECR, ECS, CloudWatch, and PassRole permissions. The following is for reference only — you **don't** need to create these manually.

The AWS credentials/role used by Jenkins needs these permissions:

### ECR Permissions
```json
{
  "Effect": "Allow",
  "Action": [
    "ecr:GetAuthorizationToken",
    "ecr:BatchCheckLayerAvailability",
    "ecr:GetDownloadUrlForLayer",
    "ecr:BatchGetImage",
    "ecr:PutImage",
    "ecr:InitiateLayerUpload",
    "ecr:UploadLayerPart",
    "ecr:CompleteLayerUpload",
    "ecr:CreateRepository",
    "ecr:DescribeRepositories",
    "ecr:PutLifecyclePolicy"
  ],
  "Resource": "*"
}
```

### ECS Permissions
```json
{
  "Effect": "Allow",
  "Action": [
    "ecs:RegisterTaskDefinition",
    "ecs:DeregisterTaskDefinition",
    "ecs:ListTaskDefinitions",
    "ecs:DescribeTaskDefinition",
    "ecs:UpdateService",
    "ecs:DescribeServices",
    "ecs:CreateCluster",
    "ecs:DescribeClusters"
  ],
  "Resource": "*"
}
```

### CloudWatch Logs Permissions
```json
{
  "Effect": "Allow",
  "Action": [
    "logs:CreateLogGroup",
    "logs:CreateLogStream",
    "logs:PutLogEvents",
    "logs:DescribeLogGroups"
  ],
  "Resource": "*"
}
```

### IAM Pass Role (required for ECS task definitions)
```json
{
  "Effect": "Allow",
  "Action": "iam:PassRole",
  "Resource": [
    "arn:aws:iam::<account-id>:role/ecsTaskExecutionRole",
    "arn:aws:iam::<account-id>:role/cicd-node-app-task-role"
  ]
}
```

---

## 📡 CloudWatch Logging & Monitoring

### How Logging Works

The ECS task definition (in `ecs/taskdef.template.json`) is configured to use the **awslogs** log driver:

```json
"logConfiguration": {
  "logDriver": "awslogs",
  "options": {
    "awslogs-group": "/ecs/cicd-node-app",
    "awslogs-region": "eu-central-1",
    "awslogs-stream-prefix": "ecs"
  }
}
```

This means all `console.log()` output from your app automatically appears in CloudWatch.

### View Logs

```bash
# View the latest logs from CloudWatch
aws logs tail /ecs/cicd-node-app --follow --region eu-central-1

# View logs from a specific time period
aws logs filter-log-events \
  --log-group-name /ecs/cicd-node-app \
  --start-time $(date -d '1 hour ago' +%s000) \
  --region eu-central-1
```

Or use the **AWS Console → CloudWatch → Log groups → /ecs/cicd-node-app**.

### Setting Up Alarms (from Project-Monitoring)

If you have monitoring alarms from a previous project, point them at:
- **ECS CPU/Memory utilization** metrics
- **CloudWatch log group** `/ecs/cicd-node-app` for error patterns
- **ECS service** event logs for deployment failures

---

## 🧹 Cleanup Guide

> ⚠️ **Do this when you're done** to avoid ongoing AWS charges!

### Option 1: Terraform Destroy (Recommended — removes EVERYTHING)

```bash
cd terraform
terraform destroy
```

Terraform will ask: `Do you really want to destroy all resources?` Type **`yes`** and press Enter.

**This deletes everything** that Terraform created: ECS cluster, ECR repo, IAM roles, security groups, CloudWatch logs, Jenkins EC2, VPC — everything.

### Option 2: Just Stop ECS (Keep Infrastructure)

If you want to keep the infrastructure but stop paying for running containers:

```bash
aws ecs update-service \
  --cluster cicd-node-cluster \
  --service cicd-node-service \
  --desired-count 0 \
  --region eu-central-1
```

Then later, to start again:

```bash
aws ecs update-service \
  --cluster cicd-node-cluster \
  --service cicd-node-service \
  --desired-count 1 \
  --region eu-central-1
```

### Clean Up Local Docker Images

```bash
docker image rm cicd-node-app:local 2>/dev/null
docker system prune -af
```

### Or Use the Makefile

```bash
make clean     # cleans node_modules, coverage, and Docker images
make destroy   # runs terraform destroy
```

---

## 🔧 Troubleshooting (Common Errors)

### ❌ "Missing required parameter: AWS_ACCOUNT_ID"

**Cause:** You ran the Jenkins build without filling in the required fields.

**Fix:** Click "Build with Parameters" and fill in `AWS_ACCOUNT_ID`, `ECS_EXECUTION_ROLE_ARN`, and `ECS_TASK_ROLE_ARN`.

---

### ❌ "Required report not found: reports/sca/dependency-check-report.json"

**Cause:** The OWASP Dependency-Check stage failed or didn't produce a report.

**Fix:** Check the console output for the SCA stage. Possible issues:
- Docker socket permissions (Jenkins can't run Docker containers)
- Network issues (OWASP DC needs to download vulnerability databases)

---

### ❌ "SCA Error: Error generating the report for cicd-node-app (Exit Code 12)"

**Cause:** This typically occurs with OWASP Dependency-Check when it fails to write the report file due to folder permissions inside the container or a corrupted data directory. It can also happen if Jenkins is running an old version of the `Jenkinsfile` before the optimization.

**Fix:** 
1. **Push latest changes:** Ensure you have pushed the updated `Jenkinsfile` that uses `npm audit` instead of OWASP. Use `git push` to sync your local changes.
2. **Permission Check:** If still using OWASP, ensure the Jenkins user has write access to the `reports/` directory on the host: `sudo chmod -R 777 reports/`.
3. **Switch to npm audit:** Verify that your `Jenkinsfile` is using the optimization: `npm audit --omit=dev --json > ${SCA_DIR}/npm-audit-report.json`.

---

### ❌ "Security gate failed. Critical/High vulnerabilities or secrets were detected."

**Cause:** The pipeline did exactly what it should — it found vulnerabilities!

**Fix:** This is expected behavior. Check the reports in `reports/sca/` and `reports/image/` to see what was found. Fix the vulnerable dependency and push again.

---

### ❌ "Cannot connect to the Docker daemon"

**Cause:** Jenkins doesn't have access to the Docker socket.

**Fix:**
```bash
# On the Jenkins server/agent:
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins

# If Jenkins is in Docker, make sure you mounted the socket:
# -v /var/run/docker.sock:/var/run/docker.sock
```

---

### ❌ "Error: reading CloudWatch Metric Alarm... empty result"

**Cause:** Terraform attempted to manage a CloudWatch alarm that was recently moved from one module (e.g., `ecs`) to another (e.g., `monitoring`), but the resource remained in the AWS environment without a corresponding state entry in the new module.

**Fix:** Use `terraform import` to manually bring the orphaned resource into the new module's state:
```bash
terraform import 'module.monitoring.aws_cloudwatch_metric_alarm.ecs_cpu[0]' cicd-pipeline-dev-ecs-high-cpu
terraform import 'module.monitoring.aws_cloudwatch_metric_alarm.ecs_memory[0]' cicd-pipeline-dev-ecs-high-memory
```
Then run `terraform apply` again.

---

---

### ❌ "aws ecs wait services-stable" times out

**Cause:** The ECS service can't reach a stable state (container keeps crashing).

**Fix:**
1. Check CloudWatch logs: `aws logs tail /ecs/cicd-node-app --region eu-central-1`
2. Check that the security group allows inbound traffic on port 5000
3. Check that the container health check passes locally first

---

### ❌ "no basic auth credentials" when pushing to ECR

**Cause:** ECR login expired or failed.

**Fix:** The pipeline runs `aws ecr get-login-password` automatically. Make sure:
- AWS CLI is installed on Jenkins agent
- AWS credentials are configured
- The region is correct

---

### ❌ SonarQube errors when `ENABLE_SONARQUBE=false`

**Cause:** SonarQube stages should be skipped when disabled.

---

## 🚨 Recent Updates & Engineering Challenges

During the development and hardening of this pipeline, several critical challenges were encountered and resolved:

### ⚡ SCA Performance Optimization
**Challenge:** OWASP Dependency-Check was adding 10-15 minutes to every build due to the requirement of downloading the entire National Vulnerability Database (NVD) on every run.
**Solution:** Replaced OWASP with `npm audit`. By using `npm audit --omit=dev --json`, the scanner now performs near-instant checks against the local dependency tree while ignoring non-production development tools, significantly reducing build friction without sacrificing security.

### 🛡️ Container & Task Hardening
**Challenge:** The default ECS task configuration allowed for more runtime permission than necessary, increasing the impact of a potential container breakout.
**Solution:** Hardened the `taskdef.template.json` by:
- Setting `readonlyRootFilesystem: true` to prevent modifications to the container OS at runtime.
- Adding `linuxParameters` to **drop ALL** kernel capabilities.

### 📉 Monitoring Module Centralization
**Challenge:** Moving CloudWatch alarms from the `ecs` module to a centralized `monitoring` module caused Terraform to lose track of the existing alarms, resulting in "empty result" errors during apply.
**Solution:** Transitioned to a unified observability model by merging ECS metrics into the monitoring module and using `terraform import` to successfully bridge the state gap for existing cloud resources.

### 🕵️ New Linting Layers
Implemented **Hadolint** for Dockerfile validation and **ShellCheck** for deployment script integrity. These tools catch best-practice violations (like running as root or missing pipefails) before the code even reaches the build stage.

### 🔑 Session Token Management
Managed multiple instances of `ExpiredToken` errors during AWS CLI and Terraform operations by implementing robust session refresh procedures and correctly handling MFA-backed AWS sessions.

## 🛠️ Makefile Commands (Quick Reference)

| Command | What it does |
|---------|-------------|
| `make help` | Shows all available commands |
| `make install` | Runs `npm ci` |
| `make test` | Runs `npm test` (Jest) |
| `make lint` | Runs ESLint |
| `make build` | Builds Docker image locally |
| `make run` | Starts the app with `npm start` |
| `make clean` | Removes `node_modules`, `coverage`, prunes Docker |
| `make deploy` | Runs Terraform apply (infrastructure) |
| `make destroy` | Runs Terraform destroy (tears down infrastructure) |

---

## ❓ Frequently Asked Questions (FAQ)

### Q: Do I need SonarQube to run this project?
**A:** No! SonarQube is optional. Keep `ENABLE_SONARQUBE` set to `false` and the SAST/Quality Gate stages will be skipped. The other security scans (npm audit, Trivy, Gitleaks, Syft) will still run.

### Q: What does the pipeline actually deploy?
**A:** The `app.js` Node.js server inside a Docker container, running on AWS ECS Fargate. The container listens on port 5000.

### Q: Why does `package.json` have `lodash 4.17.11`?
**A:** That version is intentionally old and vulnerable. It's used to demonstrate the security gate. The `inject-vulnerable-dependency.sh` and `remove-vulnerable-dependency.sh` scripts toggle this.

### Q: How much does this cost on AWS?
**A:** Rough estimates (varies by region):
- ECS Fargate (1 task, 0.25 vCPU, 0.5 GB): ~$10/month
- ECR: ~$0.10/GB/month for storage
- CloudWatch Logs: ~$0.50/GB ingested
- **Tip:** Always clean up when done!

### Q: Can I use GitHub Actions instead of Jenkins?
**A:** The pipeline is written as a `Jenkinsfile`, but the same concepts apply to GitHub Actions. You'd translate each stage into a workflow step.

### Q: What's the difference between `build-*`, `sha-*`, and `latest` tags?
**A:**
- `build-42-a1b2c3d4` → Unique tag for each build (build number + git SHA)
- `sha-a1b2c3d4` → Tag based on the git commit SHA alone
- `latest` → Always points to the most recent build. Useful for quick testing but not recommended for production.

### Q: What is `awsvpc` network mode?
**A:** Each ECS task gets its own Elastic Network Interface (ENI) with a private IP. This is required for Fargate and provides better network isolation.

### Q: How do I see my deployed app?
**A:** After successful deployment:
1. Go to **AWS Console → ECS → Clusters → cicd-node-cluster → Services → cicd-node-service → Tasks**
2. Click on the running task
3. Find the public IP (if `assignPublicIp=ENABLED`)
4. Open `http://<public-ip>:5000/health`

### Q: What if I get charged too much?
**A:** Follow the [Cleanup Guide](#-cleanup-guide) immediately. The biggest costs are Fargate tasks and NAT Gateways (if used). Always set desired count to 0 when not testing.

---

## 📚 Documentation Links

| Document | Location | Description |
|----------|----------|-------------|
| Secure CI/CD ECS Guide | `docs/SECURE-CICD-ECS.md` | Detailed setup, deployment flow, and validation procedure |
| Runbook | `RUNBOOK.md` | Operational guide with step-by-step instructions |
| Evidence Checklist | `evidence/README.md` | What to capture for project submission |

### External References

- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [Jenkins Pipeline Documentation](https://www.jenkins.io/doc/book/pipeline/)
- [OWASP Dependency-Check](https://owasp.org/www-project-dependency-check/)
- [Trivy Container Scanner](https://trivy.dev/)
- [Gitleaks Secret Scanner](https://github.com/gitleaks/gitleaks)
- [Syft SBOM Generator](https://github.com/anchore/syft)
- [SonarQube](https://www.sonarqube.org/)
- [Docker Documentation](https://docs.docker.com/)
- [Node.js Documentation](https://nodejs.org/docs/)

---

## 📝 Suggested Learning Path

If you're completely new, follow this order:

1. **Run the app locally** → [Step 1](#-step-1-run-the-app-locally-try-this-first)
2. **Run with Docker** → [Step 2](#-step-2-run-with-docker-locally)
3. **Read the key concepts** → [Key Concepts](#-key-concepts-for-beginners)
4. **Read the pipeline stages** → [Pipeline Stages](#-pipeline-stages-explained-all-19-steps)
5. **Set up AWS** → [Step 3](#-step-3-set-up-aws-ecr--ecs)
6. **Set up Jenkins** → [Step 4](#-step-4-set-up-jenkins)
7. **Run the pipeline** → [Step 5](#-step-5-run-the-pipeline)
8. **Test the security gate** → [Step 6](#-step-6-test-the-security-gate-fail-then-pass)
9. **Clean up** → [Cleanup Guide](#-cleanup-guide)

---

*Built with ❤️ for learning secure DevOps practices.*
