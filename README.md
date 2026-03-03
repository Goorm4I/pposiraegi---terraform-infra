# pposiraegi---terraform-infra
Infrastructure as Code practice repository using Terraform (AWS, Kubernetes, Networking)


[아키텍처 구조]
Users
  │
  │ HTTPS
  ▼
        ┌──────────────────────────────┐
        │             VPC              │
        │         10.0.0.0/16          │
        │                              │
        │   ┌──────────────┐ ┌──────────────┐
        │   │  AZ-A        │ │  AZ-B        │
        │   │              │ │              │
        │   │ Public-A     │ │ Public-B     │
        │   │  - ALB       │ │  - ALB       │
        │   │  - Bastion   │ │              │
        │   │              │ │              │
        │   │ Private-AppA │ │ Private-AppB │
        │   │  - EC2       │ │  - EC2       │
        │   │              │ │              │
        │   │              │ │              │
        │   └──────────────┘ └──────────────┘
        │            │
        │            │
        │       RDS (Multi-AZ)
        │
        └──────────────────────────────┘


[CIDR 설계]
Public-A  : 10.0.1.0/24
Public-B  : 10.0.2.0/24

Private-A : 10.0.11.0/24
Private-B : 10.0.12.0/24
