# TODO(김채아): export repository URLs and ARNs needed by GitHub Actions and EKS manifests.

output "repository_urls" {
  description = "ECR repository URLs by service key."
  value = {
    for key, repo in aws_ecr_repository.service :
    key => repo.repository_url
  }
}

output "repository_arns" {
  description = "ECR repository ARNs by service key."
  value = {
    for key, repo in aws_ecr_repository.service :
    key => repo.arn
  }
}

output "repository_names" {
  description = "ECR repository names by service key."
  value = {
    for key, repo in aws_ecr_repository.service :
    key => repo.name
  }
}
