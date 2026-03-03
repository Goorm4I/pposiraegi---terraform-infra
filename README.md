# pposiraegi---terraform-infra

Infrastructure as Code practice repository using Terraform (AWS, Networking, RDS)

---

## 📌 Architecture Overview

```text
Users
  │
  │ HTTPS
  ▼
        ┌────────────────────────────────────┐
        │                VPC                 │
        │            10.0.0.0/16             │
        │                                    │
        │   ┌──────────────┐  ┌──────────────┐
        │   │    AZ-A      │  │    AZ-B      │
        │   │              │  │              │
        │   │  Public-A    │  │  Public-B    │
        │   │   - ALB      │  │   - ALB      │
        │   │   - Bastion  │  │              │
        │   │              │  │              │
        │   │ Private-AppA │  │ Private-AppB │
        │   │   - EC2      │  │   - EC2      │
        │   │              │  │              │
        │   └──────────────┘  └──────────────┘
        │             │
        │             │
        │        RDS (Multi-AZ)
        │
        └────────────────────────────────────┘
```

---

## 📌 CIDR Design

| Subnet Name | CIDR Block     | Purpose |
|-------------|---------------|----------|
| Public-A    | 10.0.1.0/24   | ALB / Bastion |
| Public-B    | 10.0.2.0/24   | ALB |
| Private-A   | 10.0.11.0/24  | Backend EC2 |
| Private-B   | 10.0.12.0/24  | Backend EC2 |

---

## 📁 Terraform Structure

```text
main.tf            → AWS resources (VPC, Subnets, EC2, ALB, RDS)
variables.tf       → Variable definitions
outputs.tf         → Output values (ALB DNS, RDS endpoint, etc.)
terraform.tfvars   → Actual variable values (⚠ Not uploaded to public GitHub)
.gitignore         → State file & secret protection
```

---

## 🔐 Security Notice

The following files are **NOT committed to public repository**:

- `terraform.tfvars`
- `*.tfstate`
- `*.tfstate.backup`
- `.terraform/`

`terraform.tfvars` contains:

- SSH public key path
- Personal IP address
- RDS master username
- RDS master password

These values must remain private.

---

## 🚀 How to Run

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

---

## ⚠ Cost Warning

This infrastructure creates:

- 3 EC2 instances
- 1 Application Load Balancer
- 1 RDS (Multi-AZ)

RDS Multi-AZ incurs additional cost.

---

## 📌 Future Improvements

- Replace Bastion with SSM Session Manager
- Add HTTPS via ACM
- Implement Auto Scaling Group
- Remote backend with S3 + DynamoDB
