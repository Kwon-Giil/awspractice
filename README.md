# Cloud Operations: Terraform AWS Multi-Tier VPC Infrastructure

AWS 환경에서 안전하고 확장 가능한 **멀티 티어(Multi-Tier) 네트워크 인프라**를 Terraform(IaC)을 이용해 코드로 정의하고 프로비저닝한 프로젝트입니다.

---

## 1. 프로젝트 개요 (Overview)
* **목적:** 수동 콘솔 작업을 배제하고, IaC를 통한 선언적 인프라 구축 및 생명주기 관리 실습
* **주요 기술:** `Terraform`, `AWS (VPC, IGW, NAT Gateway, EIP, Subnet, Route Table, Security Group)`
* **기간:** 2026.10.19 ~ 2026.10.26

---

## 2. 아키텍처 구조 (Architecture)
* **VPC CIDR:** `10.0.0.0/16`
* **Public Subnet (2개 AZ 이중화):** 인터넷 직접 통신 가능 (Public Route Table + IGW 연결)
* **Private Subnet (2개 AZ 이중화):** 외부 직접 접근 차단, 안전한 내부 통신 (Private Route Table + NAT Gateway 연결)
* **Security Group:**
  * `web-sg`: 외부 HTTP(80), SSH(22) 허용
  * `private-db-sg`: 외부 차단, 오직 `web-sg`로부터의 3306 포트 접근만 허용

---

## 3. 디렉토리 구조 (Directory Structure)
project-root/
├── providers.tf         # AWS 프로바이더 및 버전 설정
├── variables.tf         # 프로젝트 전역 변수 (CIDR, 프로젝트명 등)
├── main.tf              # VPC, 서브넷, 게이트웨이, 라우팅, 보안 그룹 정의
└── outputs.tf           # 주요 리소스 ID 출력 (VPC, 서브넷 ID 등)

---

## 4. 핵심 구현 포인트 (Key Features)
1. **고가용성(High Availability) 및 이중화**
   * 멀티 AZ(`ap-northeast-2a`, `ap-northeast-2b`)에 퍼블릭/프라이빗 서브넷을 대칭적으로 배치하여 장애 대응 구조 설계
2. **보안성 강화 (Network Isolation)**
   * 프라이빗 서브넷 내 리소스는 단방향 NAT Gateway를 통해서만 외부 패치/업데이트가 가능하도록 통제
   * 최소 권한 원칙(Least Privilege)에 기반한 Security Group 인바운드/아웃바운드 규칙 설정
3. **비용 최적화 및 생명주기 관리**
   * Terraform(`terraform apply` / `terraform destroy`)을 통한 신속한 인프라 배포 및 철거로 불필요한 클라우드 과금 원천 차단
