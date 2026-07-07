# METADATA
# title: Workload containers must define liveness and readiness probes
# description: >-
#   모든 컨테이너는 livenessProbe + readinessProbe 를 정의해야 한다.
#   readiness 없으면 트래픽 급증(티켓 오픈) 시 준비 안 된 파드로 라우팅되어 예약 실패,
#   liveness 없으면 행(hang)된 파드가 자동 복구되지 않는다.
#   참고: k8s 공식 '구성 모범 사례' + 국내 운영 블로그(finda/무스마 등) probe 가이드.
#   severity 정책: 본 플랫폼은 부하 급증 대응이 핵심이라 probe 누락을 릴리스 차단급(HIGH)으로 둔다.
# scope: package
# custom:
#   id: TP003
#   severity: HIGH
#   input:
#     selector:
#       - type: kubernetes
package user.kubernetes.TP003

deny[res] {
	c := input.spec.template.spec.containers[_]
	not c.livenessProbe
	msg := sprintf("container '%s' is missing livenessProbe.", [c.name])
	res := result.new(msg, c)
}

deny[res] {
	c := input.spec.template.spec.containers[_]
	not c.readinessProbe
	msg := sprintf("container '%s' is missing readinessProbe.", [c.name])
	res := result.new(msg, c)
}
