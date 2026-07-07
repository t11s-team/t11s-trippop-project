# 인프라/Terraform 가이드

Terraform 변경은 비용, 네트워크, 배포 권한에 직접 영향을 준다. 모든 변경은 모듈 오너가 설계하고 apply 담당자가 최종 반영한다.

## 인프라 요약

```text
Cloud VPC (10.0.0.0/16)
├─ Public Subnet: ALB, NAT Gateway
├─ Private App Subnet: EKS Node Group
└─ EKS: reservation, event, user, admin 서비스

VPC Peering

On-Prem Simulation VPC (172.16.0.0/16)
├─ Public Subnet: Admin EC2 (SSM 기반 베스천)
├─ Private DB Subnet: DB EC2 + Docker MariaDB 10.11
└─ VPC Endpoints: SSM, EC2 Messages, SSM Messages, Secrets Manager, S3
```

## 모듈 오너십

| 모듈 | 경로 | 오너 | apply |
| --- | --- | --- | --- |
| Cloud/On-Prem VPC, Peering | `infra/modules/cloud-vpc`, `onprem-vpc`, `peering` | 이성호 | 이성호 |
| EKS | `infra/modules/eks` | 김건호 | 이성호 |
| EKS Add-ons | `infra/modules/eks-addons` | 김건호 + 이성호 | 이성호 |
| IAM/OIDC/IRSA | `infra/modules/iam` | 이창하 | 이성호 |
| DB EC2 | `infra/modules/ec2-db` | 이창하 | 이성호 |
| Admin EC2 | `infra/modules/ec2-admin` | 김재백 | 이성호 |
| ECR/S3 Frontend | `infra/modules/ecr`, `s3-frontend` | 김채아 | 이성호 |
| S3 Images/DB Backup | `infra/modules/s3-images`, `s3-db-backup` | 이창하 | 이성호 |
| Monitoring/Logs | `infra/modules/monitoring`, `s3-logs` | 성지수 | 성지수/이성호 |

## 작업 기준

```bash
cd infra/envs/team-dev
terraform fmt -recursive
terraform validate
```

Plan을 실행할 때는 항상 tfvars를 명시한다.

```bash
terraform plan \
  -var-file="terraform.workday-on.tfvars" \
  -var-file="terraform.temp-onprem-nat-off.tfvars"
```

금지:

```text
민감값 커밋
DB EC2/EBS destroy를 유발하는 변경
SG를 임의로 0.0.0.0/0에 개방
다른 오너 모듈을 합의 없이 직접 수정
Terraform state를 임의 수정
```

## 비용 관리 원칙

EKS Cluster와 Cloud NAT Gateway는 학습용 예산을 보호하기 위해 필요한 시간에만 운영한다. 세부 apply/destroy 순서와 자동화 스크립트는 TF Release 담당자의 내부 runbook으로 관리하며, 공개 온보딩 문서에는 팀원이 따라야 하는 코드 통합 규칙만 기재한다.

On-Prem DB VPC는 NAT Gateway 대신 SSM, EC2 Messages, SSM Messages, Secrets Manager, S3 VPC Endpoint를 사용한다. NAT Gateway는 DB EC2 패키지 업데이트처럼 외부 인터넷 접근이 필요한 경우에만 TF Release 담당자에게 요청한다.

## Terraform 통합 흐름

Terraform 변경은 항상 `modules`에서 재사용 가능한 계약을 만들고, `envs/team-dev`에서 실제 환경 값과 모듈 간 연결을 완성한다.

1. 요청자가 변경 목적과 필요한 권한/리소스를 정리한다.
2. 모듈 오너가 `infra/modules/<module>`에 변수, 리소스, output을 추가한다.
3. `team-dev` 담당자가 `infra/envs/team-dev`에서 모듈 입력값을 연결한다.
4. apply 담당자가 plan을 확인하고 실제 AWS 반영 여부를 결정한다.
5. PR에는 변경 모듈, 영향 범위, 검증 결과, apply 요청 여부를 남긴다.

## 파일별 책임

| 파일 | 역할 |
| --- | --- |
| `infra/modules/<module>/variables.tf` | 모듈이 외부에서 받는 입력 계약 |
| `infra/modules/<module>/main.tf` | 실제 AWS 리소스 선언 |
| `infra/modules/<module>/outputs.tf` | 다른 모듈이나 env에서 참조할 결과값 |
| `infra/envs/team-dev/variables.tf` | dev 환경에서 주입 가능한 입력값 |
| `infra/envs/team-dev/main.tf` | 모듈 호출과 모듈 간 wiring |
| `infra/envs/team-dev/*.tfvars` | dev 환경별 값. 민감값은 커밋하지 않는다 |

원칙:

```text
모듈 내부에서 다른 모듈을 직접 참조하지 않는다.
다른 모듈 값이 필요하면 output으로 공개하고 env main.tf에서 연결한다.
환경마다 달라질 값은 module variables로 열어둔다.
한 번만 쓰는 내부 계산값은 locals로 둔다.
다른 모듈이 소비하지 않는 값은 output으로 만들지 않는다.
```

## 예시 1: IAM에서 EKS Access Entry 권한 추가

요구사항: 팀원이 `kubectl get pods -A` 같은 EKS 조회/운영 명령을 사용할 수 있도록 IAM User에 EKS Cluster Admin Access Entry를 부여한다.

현재 구조:

```text
infra/modules/iam
└─ EKS Access Entry 리소스 정의

infra/envs/team-dev/main.tf
└─ 실제 권한을 받을 IAM User ARN 목록 전달
```

### 1. IAM 모듈 입력 정의

`infra/modules/iam/variables.tf`

```hcl
variable "eks_cluster_name" {
  description = "EKS cluster name for Access Entry API."
  type        = string
}

variable "eks_cluster_admin_user_arns" {
  description = "List of IAM user ARNs to grant EKS cluster admin access via Access Entry API."
  type        = list(string)
  default     = []
}
```

`eks_cluster_name`은 어떤 EKS Cluster에 권한을 줄지 정한다. `eks_cluster_admin_user_arns`는 권한을 받을 IAM User ARN 목록이다.

### 2. IAM 모듈 리소스 작성

`infra/modules/iam/main.tf`

```hcl
resource "aws_eks_access_entry" "team_users" {
  for_each = toset(var.eks_cluster_admin_user_arns)

  cluster_name  = var.eks_cluster_name
  principal_arn = each.value
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "team_users_admin" {
  for_each = aws_eks_access_entry.team_users

  cluster_name  = each.value.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = each.value.principal_arn

  access_scope {
    type = "cluster"
  }
}
```

`aws_eks_access_entry`는 IAM Principal을 EKS Cluster에 등록한다. `aws_eks_access_policy_association`은 등록된 Principal에 AWS 관리형 EKS Access Policy를 연결한다.

주의:

```text
AWS IAM 정책만 붙인다고 kubectl 권한이 생기지 않는다.
EKS Cluster API 접근은 aws_eks_access_entry와 aws_eks_access_policy_association까지 필요하다.
팀원별 ARN을 여러 개 받아야 하므로 count보다 for_each + toset(list)을 사용한다.
```

### 3. team-dev에서 실제 값 연결

`infra/envs/team-dev/main.tf`

```hcl
module "iam" {
  source = "../../modules/iam"

  name_prefix      = "${var.project}-${var.env}"
  common_tags      = local.common_tags
  region           = var.aws_region
  eks_cluster_name = module.eks.cluster_name

  eks_cluster_admin_user_arns = [
    "arn:aws:iam::<account-id>:user/changha",
    "arn:aws:iam::<account-id>:user/geonho",
    "arn:aws:iam::<account-id>:user/jaeback",
    "arn:aws:iam::<account-id>:user/jisu",
  ]
}
```

현재 dev 환경은 `team-dev/main.tf`에서 팀원 ARN 목록을 직접 넘긴다. 팀원이 자주 바뀌거나 환경별로 목록이 달라질 경우에는 root variable로 승격한다.

`infra/envs/team-dev/variables.tf`

```hcl
variable "eks_cluster_admin_user_arns" {
  description = "IAM user ARNs allowed to administer the dev EKS cluster."
  type        = list(string)
  default     = []
}
```

`infra/envs/team-dev/main.tf`

```hcl
module "iam" {
  source = "../../modules/iam"

  eks_cluster_name            = module.eks.cluster_name
  eks_cluster_admin_user_arns = var.eks_cluster_admin_user_arns
}
```

`infra/envs/team-dev/terraform.workday-on.tfvars`

```hcl
eks_cluster_admin_user_arns = [
  "arn:aws:iam::<account-id>:user/changha",
  "arn:aws:iam::<account-id>:user/geonho",
]
```

### 4. output 작성 기준

Access Entry는 다른 모듈에서 다시 참조하지 않으므로 보통 output이 필요 없다. output은 다른 모듈이나 운영자가 소비할 값이 있을 때만 만든다.

필요한 경우:

`infra/modules/iam/outputs.tf`

```hcl
output "eks_cluster_admin_user_arns" {
  description = "IAM user ARNs granted EKS cluster admin access."
  value       = var.eks_cluster_admin_user_arns
}
```

불필요한 경우:

```text
단순 생성 여부 확인용 output
민감값 output
다른 모듈에서 쓰지 않는 ARN 목록 output
```

### 5. PR 요청 메시지 예시

```text
[Terraform 변경 요청]
모듈: infra/modules/iam
목적: 팀원 IAM User에 EKS Access Entry 권한 부여
추가 리소스:
- aws_eks_access_entry.team_users
- aws_eks_access_policy_association.team_users_admin

team-dev 통합 요청:
- module.iam.eks_cluster_name = module.eks.cluster_name
- module.iam.eks_cluster_admin_user_arns에 권한 대상 IAM User ARN 추가

검증:
- terraform fmt -recursive
- terraform validate
- terraform plan -target=module.iam

주의:
- IAM 정책만으로는 kubectl 권한이 생기지 않음
- Access Entry API 리소스가 함께 생성되어야 함
- 권한 대상 ARN 오타 확인 필요
```

## 예시 2: 다른 모듈이 IAM Role ARN을 필요로 하는 경우

요구사항: EKS Add-ons 모듈이 AWS Load Balancer Controller용 IRSA Role ARN을 필요로 한다.

IAM 모듈은 Role을 만들고 output으로 공개한다.

`infra/modules/iam/outputs.tf`

```hcl
output "lb_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller IRSA."
  value       = aws_iam_role.lb_controller.arn
}
```

EKS Add-ons 모듈은 Role ARN을 입력으로 받는다.

`infra/modules/eks-addons/variables.tf`

```hcl
variable "lb_controller_role_arn" {
  description = "IAM role ARN used by AWS Load Balancer Controller service account."
  type        = string
}
```

`team-dev`에서 두 모듈을 연결한다.

`infra/envs/team-dev/main.tf`

```hcl
module "eks_addons" {
  source = "../../modules/eks-addons"

  cluster_name           = module.eks.cluster_name
  lb_controller_role_arn = module.iam.lb_controller_role_arn
}
```

이 패턴을 사용하면 `eks-addons` 모듈이 IAM 모듈의 내부 리소스 이름을 몰라도 된다. 모듈 간 계약은 output과 variable로만 연결한다.

## 예시 3: IAM 정책에 권한 추가

요구사항: GitHub Actions 배포 Role이 EKS Cluster 정보를 조회해야 한다.

`infra/modules/iam/main.tf`

```hcl
resource "aws_iam_policy" "app_eks_describe" {
  name        = "${var.name_prefix}-app-eks-describe-policy"
  description = "Allow GitHub Actions CD to describe the EKS cluster"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = "arn:aws:eks:${var.region}:*:cluster/${var.name_prefix}-eks"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "app_eks_describe_attach" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.app_eks_describe.arn
}
```

권한을 추가할 때는 가능한 한 Resource 범위를 좁힌다. 위 예시는 현재 프로젝트의 EKS Cluster 이름 규칙이 `${var.name_prefix}-eks`로 고정되어 있기 때문에 cluster ARN 패턴으로 제한한다. AWS API 특성상 Resource 제한이 어려운 경우에만 `"*"`를 사용하고, PR에 이유를 적는다.

## 통합 요청 템플릿

모듈 오너가 `team-dev` 연결을 요청할 때는 아래 형식으로 남긴다.

```text
[Terraform 통합 요청]
요청자:
담당 모듈:
변경 목적:

추가/수정 파일:
- infra/modules/<module>/variables.tf
- infra/modules/<module>/main.tf
- infra/modules/<module>/outputs.tf

team-dev 연결 필요:
- infra/envs/team-dev/main.tf
- infra/envs/team-dev/variables.tf
- infra/envs/team-dev/*.tfvars

team-dev에 전달해야 할 값:
- 변수명:
- 타입:
- 예시값:
- 민감값 여부:

다른 모듈에서 참조해야 할 output:
- output 이름:
- 참조 예시: module.<module>.<output_name>

검증:
- terraform fmt -recursive
- terraform validate
- terraform plan 결과 요약:

주의사항:
- destroy 위험 여부:
- 비용 증가 여부:
- SG/권한 변경 승인 필요 여부:
```

예시:

```text
[Terraform 통합 요청]
요청자: IAM 담당
담당 모듈: infra/modules/iam
변경 목적: 팀원 IAM User에 EKS Access Entry 권한 부여

team-dev 연결 필요:
- module.iam.eks_cluster_name = module.eks.cluster_name
- module.iam.eks_cluster_admin_user_arns = 권한 대상 IAM User ARN 목록

team-dev에 전달해야 할 값:
- 변수명: eks_cluster_admin_user_arns
- 타입: list(string)
- 예시값: ["arn:aws:iam::<account-id>:user/geonho"]
- 민감값 여부: 아님

다른 모듈에서 참조해야 할 output:
- 없음

주의사항:
- IAM 정책만 추가하면 kubectl 권한이 생기지 않음
- Access Entry와 Access Policy Association이 함께 필요함
- 기존 권한 대상이 빠지지 않도록 리스트 병합 필요
```

## SG 변경 요청 예시

DB SG는 CIDR보다 SG ID 참조를 우선한다.

```hcl
resource "aws_vpc_security_group_ingress_rule" "db_from_eks" {
  security_group_id            = aws_security_group.db_sg.id
  referenced_security_group_id = var.eks_node_sg_id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
}
```

요청 메시지:

```text
[모듈] infra/modules/ec2-db
[요청] EKS Node에서 DB 3306 접근 필요
[이유] reservation/event/user/admin 서비스 DB 연결
[변경] DB SG inbound source를 EKS Node SG로 참조
[검증] terraform plan에서 CIDR 0.0.0.0/0 미사용 확인
[승인] SG 변경 승인 후 apply 담당자 반영
```
