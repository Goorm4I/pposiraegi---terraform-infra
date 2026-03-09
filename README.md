# 🏗 AWS Terraform Infrastructure Architecture

## 📌 Architecture Overview

Users는 Route 53을 통해 도메인(pposiragi.cloud)으로 접근하며, CloudFront가 요청을 라우팅한다.  
정적 프론트엔드 파일은 CloudFront → S3(OAC)로 서빙되고,  
API 요청은 CloudFront → IGW → ALB → Private Subnet의 Backend EC2로 전달된다.  
Backend EC2는 Private Subnet의 RDS(MySQL)와 통신한다.  
개발자는 Bastion Host를 통해 Private EC2에 SSH로 접근한다.

---

## Architecture Diagram

<img width="1693" height="1292" alt="aws-architecture-v4 drawio" src="https://github.com/user-attachments/assets/11af8902-b8db-4ec9-a35e-b2fafd03bce5" />


---

## 🏗️ 인프라 구조 (Terraform / AWS)

### 📦 리소스 목록

| 리소스 | 개수 | 설명 |
|--------|------|------|
| VPC | 1 | 10.0.0.0/16 |
| Public Subnet | 4 | ALB(x2), Bastion(x1), NAT용(x1, 비활성) |
| Private Subnet | 2 | Backend EC2(x1), RDS Multi-AZ(x1) |
| Internet Gateway | 1 | Public 서브넷 인터넷 연결 |
| NAT Gateway | 0 | 현재 비활성 (주석 해제 시 활성화) |
| EC2 | 2 | Bastion, Backend |
| ALB | 1 | Backend EC2 앞단 로드밸런서 |
| RDS (MySQL) | 1 | Multi-AZ, Private 서브넷 |
| S3 | 1 | 프론트엔드 정적 파일 호스팅 |
| CloudFront | 1 | CDN, S3+ALB 통합 진입점 |
| Security Group | 4 | ALB / Bastion / App / RDS |

---

### 🔀 트래픽 흐름
```
사용자
  │
  ▼
CloudFront
  ├─ /api/*  ──────────────► ALB ──► Backend EC2 (Private)
  │                                        │
  │                                        ▼
  │                                    RDS MySQL (Private)
  │
  └─ /*  ──────────────────► S3 (프론트엔드 정적 파일)
```

---

### 🔐 Security Group 규칙

| SG 이름 | 인바운드 | 허용 출처 |
|---------|---------|----------|
| alb-sg | 80 (HTTP) | 0.0.0.0/0 |
| bastion-sg | 22 (SSH) | 내 IP만 |
| app-sg | 8080 (API) | alb-sg |
| app-sg | 22 (SSH) | bastion-sg |
| rds-sg | 3306 (MySQL) | app-sg |

---

### 🌐 주요 엔드포인트

| 항목 | 값 | 설명 |
|------|-----|------|
| 프론트엔드 URL | `https://<cloudfront-domain>` | CloudFront 도메인 (`terraform output cloudfront_url`) |
| 백엔드 API URL | `http://<alb-dns>/api/v1/...` | ALB DNS (`terraform output alb_dns`) |
| S3 버킷명 | `pposiraegi-frontend-xxxx` | 프론트 빌드 파일 업로드 대상 |
| RDS 엔드포인트 | Private 접근만 가능 | `terraform output rds_endpoint` |
| Bastion IP | Public IP | `terraform output bastion_ip` |

---

### 🚀 배포 방법

**1. 인프라 생성**
```bash
terraform init
terraform apply
```

**2. 프론트엔드 배포**
```bash
npm run build
aws s3 sync ./build s3://$(terraform output -raw s3_bucket_name) --profile goorm --delete
```

**3. Backend EC2**
- `terraform apply` 시 `user_data.sh` 자동 실행
- GitHub 레포 클론 → `docker-compose up -d` 자동 실행
- CORS 허용 오리진은 CloudFront 도메인으로 자동 설정

**4. 인프라 삭제**
```bash
terraform destroy
```

---

### 📁 파일 구성

| 파일 | 설명 |
|------|------|
| `main.tf` | 전체 AWS 리소스 정의 |
| `variables.tf` | 변수 선언 및 기본값 |
| `outputs.tf` | 배포 후 출력값 (URL, IP 등) |
| `user_data.sh` | EC2 부팅 시 자동 실행 스크립트 |
