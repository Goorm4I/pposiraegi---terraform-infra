# 🏗 AWS Terraform Infrastructure Architecture

## 📌 Architecture Overview

Users는 HTTPS를 통해 Application Load Balancer(ALB)에 접근한다.  
ALB는 Public Subnet에 위치하며 트래픽을 Private Subnet의 Backend EC2로 전달한다.  
Backend EC2는 RDS 데이터베이스와 통신한다.  
운영자는 Bastion Host를 통해 Private EC2에 접근한다.

---

# Architecture Diagram

```
Users
  │
  │ HTTPS
  ▼
        ┌───────────────────────────────┐
        │              VPC              │
        │          10.0.0.0/16          │
        │                               │
        │   ┌─────────────┐ ┌─────────────┐
        │   │    AZ-A     │ │    AZ-B     │
        │   │             │ │             │
        │   │ Public Sub  │ │ Public Sub  │
        │   │   ALB       │ │   ALB       │
        │   │             │ │             │
        │   │ Public Sub  │ │ Public Sub  │
        │   │  Bastion    │ │   (Future)  │
        │   │             │ │    NAT      │
        │   │             │ │             │
        │   │ Private Sub │ │ Private Sub │
        │   │ Backend EC2 │ │ Backend EC2 │
        │   │             │ │             │
        │   └─────────────┘ └─────────────┘
        │               │
        │               ▼
        │        RDS (Multi-AZ)
        │
        └───────────────────────────────┘
```

---

# 📡 Traffic Flow

## User Traffic

Users → ALB → Backend EC2 → RDS

```
User
 │
 ▼
Application Load Balancer
 │
 ▼
Backend EC2 (Private Subnet)
 │
 ▼
RDS (Multi-AZ)
```

---

## Admin Access

운영자는 Bastion Host를 통해 Private EC2에 접속한다.

```
Admin PC
 │
 ▼
Bastion Host
 │
 ▼
Backend EC2
```

---

# 🌐 Network Design

## VPC

| Resource | Value |
|---|---|
| VPC CIDR | 10.0.0.0/16 |
| Region | ap-northeast-2 |

---

## Subnet Design

| Subnet | CIDR | AZ | Purpose |
|---|---|---|---|
| Public-A | 10.0.1.0/24 | AZ-A | ALB |
| Public-B | 10.0.2.0/24 | AZ-B | ALB |
| Public-C | 10.0.3.0/24 | AZ-A | Bastion |
| Public-D | 10.0.4.0/24 | AZ-B | NAT / 확장 |
| Private-A | 10.0.11.0/24 | AZ-A | Backend EC2 |
| Private-B | 10.0.12.0/24 | AZ-B | Backend EC2 / RDS |

---

# 🔐 Security Design

## Bastion Security Group

| Port | Source |
|---|---|
| 22 | Admin Public IP |

관리자만 SSH 접속 가능하다.

---

## ALB Security Group

| Port | Source |
|---|---|
| 80 | 0.0.0.0/0 |
| 443 | 0.0.0.0/0 |

인터넷에서 접근 가능하다.

---

## Backend Security Group

| Port | Source |
|---|---|
| 8080 | ALB Security Group |
| 22 | Bastion Security Group |

외부에서는 직접 접근할 수 없다.

---

## RDS Security Group

| Port | Source |
|---|---|
| 3306 | Backend Security Group |

DB는 Backend 서버만 접근 가능하다.

---

# 🗄 Database Architecture

RDS는 Multi-AZ 구성을 사용한다.

```
AZ-A
 └ Primary DB

AZ-B
 └ Standby DB
```

장애 발생 시 Standby DB가 자동으로 Primary로 승격된다.

---

# ⚙ Infrastructure Components

| Component | Description |
|---|---|
| VPC | 전체 네트워크 환경 |
| Public Subnets | ALB, Bastion 배치 |
| Private Subnets | Backend EC2, RDS |
| ALB | 트래픽 분산 |
| Bastion Host | 관리 접속 |
| Backend EC2 | 애플리케이션 서버 |
| RDS | 데이터베이스 |
| NAT Gateway | Private 인터넷 접근 (확장 가능) |

---

# 🚀 Terraform Deployment

```
terraform init
terraform plan
terraform apply
```

---

# 📌 Key Architecture Characteristics

- Multi-AZ Architecture  
- Bastion 기반 Secure SSH Access  
- Private Backend Network  
- RDS Multi-AZ High Availability  
- ALB 기반 트래픽 분산  
- Terraform Infrastructure as Code  
