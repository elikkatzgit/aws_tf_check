resource "aws_ecr_repository" "ecr_repo" {
  name                 = "ecr-repo"
  image_tag_mutability = "MUTABLE"   # or "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

output "ecr_repository_url" {
  value = aws_ecr_repository.ecr_repo.repository_url
}
