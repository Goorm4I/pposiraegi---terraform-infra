# 🏗 AWS Terraform Infrastructure Architecture

## 📌 Architecture Overview

Users는 Route 53을 통해 도메인(pposiragi.cloud)으로 접근하며, CloudFront가 요청을 라우팅한다.  
정적 프론트엔드 파일은 CloudFront → S3(OAC)로 서빙되고,  
API 요청은 CloudFront → IGW → ALB → Private Subnet의 Backend EC2로 전달된다.  
Backend EC2는 Private Subnet의 RDS(MySQL)와 통신한다.  
개발자는 Bastion Host를 통해 Private EC2에 SSH로 접근한다.

---

## Architecture Diagram

<img width="1681" height="1171" alt="aws-architecture-v3 drawio" src="https://github.com/user-attachments/assets/023892ea-57c3-47c5-86cf-8a9ea8715417" />

---

# 📡 Traffic Flow

## User Traffic

```
User
 │
 ▼
Route 53 (pposiragi.cloud)
 │
 ▼
CloudFront
 ├── /* ──────────────────▶ S3 (정적 프론트엔드, OAC)
 └── /api/* ──────────────▶ Internet Gateway
                                │
                                ▼
                           ALB (Public Subnet, port 80)
                                │
                                ▼
                           Backend EC2 (Private Subnet, port 8080)
                                │
                                ▼
                           RDS MySQL (Private Subnet, Multi-AZ)
```

## Developer Access

개발자는 Bastion Host를 통해서만 Private EC2에 SSH 접속할 수 있다.  
Bastion은 등록된 관리자 IP(`my_ip`)에서만 SSH를 허용한다.

```
Developer (my_ip)
 │
 ▼
Internet Gateway
 │
 ▼
Bastion Host (Public Subnet C, port 22)
 │
 ▼
Backend EC2 (Private Subnet A, port 22)
```

---

# 🌐 Network Design

## VPC

| Resource | Value |
|---|---|
| VPC CIDR | 10.0.0.0/16 |
| Region | ap-northeast-2 (Seoul) |
| DNS Support | ✅ 활성화 |
| DNS Hostnames | ✅ 활성화 |

---

## Subnet Design

| Subnet | CIDR | AZ | Purpose |
|---|---|---|---|
| Public-A | 10.0.1.0/24 | AZ-a | ALB |
| Public-B | 10.0.2.0/24 | AZ-b | ALB (이중화) |
| Public-C | 10.0.3.0/24 | AZ-a | Bastion Host |
| Public-D | 10.0.4.0/24 | AZ-b | NAT Gateway 예정 (현재 비활성) |
| Private-A | 10.0.11.0/24 | AZ-a | Backend EC2, RDS Primary |
| Private-B | 10.0.12.0/24 | AZ-b | RDS Standby (Multi-AZ) |

### 왜 Public 서브넷을 4개로 구성했나?

- **Public-A / Public-B**: ALB는 반드시 2개 이상의 AZ에 걸쳐 있어야 한다. 따라서 각 AZ에 퍼블릭 서브넷을 하나씩 배치해 ALB 이중화를 구성했다.
- **Public-C**: Bastion Host 전용 서브넷. ALB와 Bastion을 분리해 보안 관리와 트래픽 역할을 명확히 구분했다.
- **Public-D**: 추후 NAT Gateway 활성화를 고려해 미리 확보해둔 서브넷이다.

---

# 🔐 Security Design

## Bastion Host란?

Bastion Host는 외부에서 Private 네트워크 내부로 접근하기 위한 **중간 경유 서버**다.  
Backend EC2는 Private Subnet에 있어 인터넷에서 직접 접근이 불가능하다.  
따라서 개발자는 반드시 Bastion을 통해서만 내부 서버에 SSH 접속할 수 있다.  
Bastion 자체도 등록된 관리자 IP에서만 접근 가능하도록 Security Group으로 제한한다.

## ALB Security Group

| Port | Source | 설명 |
|---|---|---|
| 80 | CloudFront IP 대역 (Prefix List) | CloudFront를 통한 요청만 허용, 직접 접근 차단 |

> ALB를 `0.0.0.0/0`으로 열지 않고 AWS 관리형 CloudFront Prefix List로 제한해 직접 접근을 차단한다.

## Bastion Security Group

| Port | Source | 설명 |
|---|---|---|
| 22 | my_ip (관리자 IP) | 등록된 관리자 IP에서만 SSH 허용 |

## Backend Security Group

| Port | Source | 설명 |
|---|---|---|
| 8080 | ALB Security Group | ALB에서 오는 트래픽만 허용 |
| 22 | Bastion Security Group | Bastion을 통한 SSH만 허용 |

## RDS Security Group

| Port | Source | 설명 |
|---|---|---|
| 3306 | Backend Security Group | Backend EC2에서만 DB 접근 허용 |

---

# 🌍 CloudFront & S3

| 항목 | 내용 |
|---|---|
| 기본 오리진 (`/*`) | S3 (정적 프론트엔드) |
| API 오리진 (`/api/*`) | ALB |
| S3 접근 방식 | OAC (Origin Access Control) — CloudFront만 접근 가능, 퍼블릭 차단 |
| HTTPS | redirect-to-https 강제 적용 |
| SPA 라우팅 | 403/404 → index.html 리다이렉트 |
| 커스텀 헤더 | `X-CloudFront-Secret` — CloudFront → ALB 직접 접근 이중 차단 |

---

# 🗄 Database Architecture

RDS MySQL은 Multi-AZ 구성으로 고가용성을 확보한다.

```
Private Subnet A (AZ-a)
 └── RDS Primary (읽기/쓰기)
        │ 자동 복제
        ▼
Private Subnet B (AZ-b)
 └── RDS Standby (장애 시 자동 Failover)
```

Primary 장애 발생 시 Standby가 자동으로 Primary로 승격된다.  
Standby는 평상시 읽기/쓰기 불가 — Failover 전용이다.

| 항목 | 값 |
|---|---|
| Engine | MySQL |
| Instance Class | db.t3.micro |
| Storage | 20GB |
| Multi-AZ | ✅ 활성화 |
| Subnet Group | private_a + private_b |

---

# ⚙ Infrastructure Components

| Component | Description |
|---|---|
| Route 53 | DNS — pposiragi.cloud → CloudFront Alias |
| ACM | HTTPS 인증서 (us-east-1, CloudFront 전용) |
| CloudFront | 글로벌 CDN, S3/ALB 오리진 분기 |
| S3 | 정적 프론트엔드 파일 (OAC, 퍼블릭 차단) |
| VPC | 전체 네트워크 환경 |
| Internet Gateway | VPC ↔ 인터넷 연결 |
| Public Subnets | ALB, Bastion 배치 (4개) |
| Private Subnets | Backend EC2, RDS 배치 (2개) |
| ALB | CloudFront에서 오는 트래픽을 Backend EC2로 분산 |
| Bastion Host | 개발자 SSH 접근용 경유 서버 |
| Backend EC2 | 애플리케이션 서버 |
| RDS MySQL | 데이터베이스, Multi-AZ |
| NAT Gateway | Private EC2 아웃바운드 인터넷 (현재 비활성, 필요 시 주석 해제) |

---

# 🚀 Terraform Deployment

```bash
# 1. terraform.tfvars에서 아래 값 반드시 변경
#    - db_password
#    - cloudfront_secret
#    - domain_name (현재: pposiragi.cloud)

# 2. 초기화 (처음 한 번만)
terraform init

# 3. 변경사항 확인
terraform plan

# 4. 배포
terraform apply
```

<br>

---

# 📌 Key Architecture Characteristics

- **Route 53 + CloudFront**: 단일 도메인 진입점, HTTPS 강제
- **S3 OAC**: 퍼블릭 차단, CloudFront만 접근 가능
- **ALB CloudFront Prefix List**: ALB 직접 접근 차단
- **Multi-AZ Architecture**: ALB, RDS 모두 다중 AZ 구성
- **Bastion 기반 Secure SSH Access**: Private EC2 직접 접근 불가
- **Private Backend Network**: EC2, RDS 모두 Private Subnet 격리
- **NAT Gateway 확장 가능**: 현재 비활성, 필요 시 주석 해제로 활성화
- **Terraform IaC**: 전체 인프라 코드화
