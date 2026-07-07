# TODO(김채아): implement the ECR module.
# Apply owner is 이성호; backup reviewer is 성지수.
# Required decisions: repository names, image tag immutability, scan-on-push, lifecycle policy, and CI/CD push permissions.

locals {
  repositories = {
    reservation_service = "t11s-dev-ecr-reservation-service"
    event_service       = "t11s-dev-ecr-event-service"
    user_service        = "t11s-dev-ecr-user-service"
    admin_service       = "t11s-dev-ecr-admin-service"
    db_mariadb          = "t11s-dev-ecr-db-mariadb"
    db_node_exporter    = "t11s-dev-ecr-db-node-exporter"
    db_mysqld_exporter  = "t11s-dev-ecr-db-mysqld-exporter"
  }
}

resource "aws_ecr_repository" "service" {
  for_each = local.repositories

  name                 = each.value
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(
    var.common_tags,
    {
      Name  = each.value
      Owner = var.owner
    }
  )
}
resource "aws_ecr_lifecycle_policy" "service" {
  for_each   = aws_ecr_repository.service
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 tagged images"
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["*"]
          countType      = "imageCountMoreThan"
          countNumber    = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
