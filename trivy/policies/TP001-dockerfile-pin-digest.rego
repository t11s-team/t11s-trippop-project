# METADATA
# title: Base image must be pinned by digest
# description: >-
#   FROM 은 가변 태그(node:22-alpine)가 아니라 불변 다이제스트(@sha256:...)로 고정해야 한다.
#   태그는 같은 이름으로 내용이 바뀔 수 있어(공급망 변조/비재현 빌드) 위험하다.
#   참고 표준: CIS Docker Benchmark 4.x(신뢰된 base 이미지 사용), SLSA(빌드 재현성/출처).
#   운영: 현재 report-only. Renovate 등 digest 자동 갱신 도입 후 게이트로 승격.
# scope: package
# custom:
#   id: TP001
#   severity: HIGH
#   input:
#     selector:
#       - type: dockerfile
package user.dockerfile.TP001

deny[res] {
	stage := input.Stages[_]
	cmd := stage.Commands[_]
	cmd.Cmd == "from"
	image := cmd.Value[0]
	not contains(image, "@sha256:")
	msg := sprintf("Base image '%s' is not pinned by digest. Use FROM <image>@sha256:<digest>.", [image])
	res := result.new(msg, cmd)
}
