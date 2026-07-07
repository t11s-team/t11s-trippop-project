# Terraform Environments

이 디렉터리는 TripPop dev 환경에 Terraform을 적용하는 진입점이다. 현재 포트폴리오 전환 작업에서는 개인 AWS 계정 profile `t11s-sungho`를 기준으로 검증한다.

## 디렉터리 기준

| 디렉터리 | AWS 프로파일 | 용도 |
| --- | --- | --- |
| `team-dev` | `t11s-sungho` | 개인 포트폴리오용 AWS dev 환경 |

## 기본 흐름

1. 각 모듈 담당자는 자기 브랜치에서 모듈 코드를 작성한다.
2. `infra/envs/team-dev`에서 `terraform init`, `terraform validate`, `terraform plan`까지 확인한다.
3. PR에 plan 결과를 공유한다.
4. 실제 `apply`는 비용과 상태 리소스 영향을 확인한 뒤 `team-dev`에서만 수행한다.

주의:

- `team-dev/providers.tf`와 로컬 환경 파일의 profile을 확인하지 않으면 다른 계정에 적용될 수 있다.
- 명령 실행 전 `aws sts get-caller-identity --profile <profile>`로 계정을 확인한다.
- `apply`와 `destroy`는 승인 없이 실행하지 않는다.
- 현재 포트폴리오 기준 기본 profile은 `t11s-sungho`이며, 개인 AWS 계정 ID는 로컬 환경과 GitHub Secrets에서만 관리한다.
