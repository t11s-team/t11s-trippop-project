# METADATA
# title: Container images must come from a private AWS ECR registry
# description: >-
#   워크로드 이미지는 사내 ECR(<account>.dkr.ecr.<region>.amazonaws.com)에서만 받아야 한다.
#   docker.io 등 외부/퍼블릭 레지스트리는 타이포스쿼팅·변조 이미지 유입 경로 → 차단.
#   참고: OPA Gatekeeper 'K8sAllowedRepos' / Kyverno 'restrict-image-registries' 표준 정책을
#         Trivy Rego로 이식. 계정 비종속(ECR 도메인 패턴으로 매칭).
# scope: package
# custom:
#   id: TP002
#   severity: HIGH
#   input:
#     selector:
#       - type: kubernetes
package user.kubernetes.TP002

is_ecr(image) {
	regex.match(`^[0-9]{12}\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com/`, image)
}

deny[res] {
	c := input.spec.template.spec.containers[_]
	not is_ecr(c.image)
	msg := sprintf("container '%s' image '%s' is not from an approved AWS ECR registry.", [c.name, c.image])
	res := result.new(msg, c)
}

deny[res] {
	c := input.spec.template.spec.initContainers[_]
	not is_ecr(c.image)
	msg := sprintf("initContainer '%s' image '%s' is not from an approved AWS ECR registry.", [c.name, c.image])
	res := result.new(msg, c)
}
