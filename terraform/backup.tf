# # efs.tf
# resource "aws_security_group" "efs" {
#   name   = "shopware-efs-sg"
#   vpc_id = aws_vpc.main.id

#   ingress {
#     from_port       = 2049
#     to_port         = 2049
#     protocol        = "tcp"
#     security_groups = [aws_security_group.ecs.id]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = { Name = "shopware-efs-sg" }
# }

# resource "aws_efs_file_system" "media" {
#   creation_token = "shopware-media"
#   tags           = { Name = "shopware-media-efs" }
# }

# resource "aws_efs_mount_target" "mt" {
#   for_each        = aws_subnet.private
#   file_system_id  = aws_efs_file_system.media.id
#   subnet_id       = each.value.id
#   security_groups = [aws_security_group.efs.id]
# }

