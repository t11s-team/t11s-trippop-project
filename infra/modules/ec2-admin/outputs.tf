output "admin_public_ip" {
  description = "Admin EC2의 공인 IP 주소"
  value       = aws_eip.admin_eip.public_ip
}

# [요청사항 반영] 생성된 인스턴스 프로파일 이름 출력
output "admin_ec2_instance_profile_name" {
  description = "생성된 Admin EC2 인스턴스 프로파일 이름"
  value       = aws_iam_instance_profile.admin_ec2.name
}