# resource "aws_ecr_repository" "shopware" {
#   name                 = "shopware-imperial=apotheke"
#   image_tag_mutability = "MUTABLE"

#   tags = { Name = "shopware-ecr" }
# }

# output "ecr_repository_url" {
#   value       = aws_ecr_repository.shopware.repository_url
#   description = "URL of the Shopware ECR repo"
# }